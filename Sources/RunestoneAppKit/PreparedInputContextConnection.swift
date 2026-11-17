#if canImport(AppKit)
import AppKit
import ObjectiveC

/// Internal input-context lifecycle for a prepared session. This is not a view,
/// event responder, or public editor. All operations run on the main thread.
final class PreparedInputContextConnection {
    protocol Driver: AnyObject {
        var associationTarget: NSObject { get }
        /// Must return the underlying context without callouts.
        var inputContext: NSTextInputContext? { get }
        func activate()
        func handle(_ event: NSEvent) -> Bool
        func invalidateCoordinates()
        func discardMarkedText()
        func deactivate()
    }
    protocol ReadyObserver: AnyObject {
        func preparedInputContextConnectionDidBecomeReady(_ connection: PreparedInputContextConnection)
    }
    /// The responder must interpret commands or pass unsupported selectors on
    /// through its responder chain. The connection does not retain the handler.
    protocol CommandHandler: AnyObject {
        func preparedInputContextConnection(_ connection: PreparedInputContextConnection, doCommand selector: Selector)
    }
    /// Each record concerns one callback or dispatch attempt, never the
    /// outcome of a whole input-method event and never authorizes replay.
    enum InputOperation: Equatable {
        case insertText, setMarkedText, unmarkText, cancelComposition, setSelection
        case command, undispatchedKey, keyBindingFallback, inputDispatchInterrupted, compositionDiscarded
    }
    struct InputFailureRecord: Equatable {
        let operation: InputOperation
        let failure: PreparedInputEventAdapter.InputFailure
    }
    struct InputFailureBatch: Equatable {
        let records: [InputFailureRecord]
        /// Additional records dropped after capacity, saturating at Int.max.
        let overflowCount: Int
    }
    protocol InputFailureObserver: AnyObject {
        /// Asynchronous, after driver, client and adapter activity has unwound.
        /// The owner acknowledges and clears by taking the batch explicitly.
        func preparedInputContextConnectionHasInputFailures(_ connection: PreparedInputContextConnection)
    }
    enum KeyDispatchOutcome: Equatable { case handled, declined, unavailable }

    typealias DriverFactory = (NSTextInputClient) -> Driver
    private enum State { case connected, resetRequested, quiescing, reconstructing, waiting, disconnected }

    // These are the only strong references to AppKit-owning objects and
    // closures. The payload is transferred to the main queue during deinit.
    private final class Payload {
        let adapter: PreparedInputEventAdapter
        let view: ReadOnlyDocumentView
        let makeDriver: DriverFactory
        let schedule: (@escaping () -> Void) -> Void
        let blocked: () -> Void
        var driver: Driver?
        var proxy: PreparedContextClient?
        var contextToken: PreparedInputEventAdapter.InputContextToken?

        init(adapter: PreparedInputEventAdapter, view: ReadOnlyDocumentView,
             makeDriver: @escaping DriverFactory,
             schedule: @escaping (@escaping () -> Void) -> Void,
             blocked: @escaping () -> Void, token: PreparedInputEventAdapter.InputContextToken) {
            self.adapter = adapter
            self.view = view
            self.makeDriver = makeDriver
            self.schedule = schedule
            self.blocked = blocked
            self.contextToken = token
        }
    }
    private var payload: Payload?
    private var adapter: PreparedInputEventAdapter { payload!.adapter }
    private var view: ReadOnlyDocumentView { payload!.view }
    private var makeDriver: DriverFactory { payload!.makeDriver }
    // Must enqueue asynchronously without running a nested event loop.
    private var schedule: (@escaping () -> Void) -> Void { payload!.schedule }
    private var blocked: () -> Void { payload!.blocked }
    private var driver: Driver? {
        get { payload!.driver }
        set { payload!.driver = newValue }
    }
    private var proxy: PreparedContextClient? {
        get { payload!.proxy }
        set { payload!.proxy = newValue }
    }
    private var textCheckingController: NSTextCheckingController?
    private let textCheckingAnnotations = PreparedInputTextCheckingAnnotations()
    private struct SpellingCorrection {
        let range: NSRange
        let original: String
        let replacement: String
        let language: String
        var revision: UUID
    }
    private var spellingCorrection: SpellingCorrection?
    private var spellingIndicatorID: UUID?
    private var contextToken: PreparedInputEventAdapter.InputContextToken? {
        get { payload!.contextToken }
        set { payload!.contextToken = newValue }
    }
    private var state: State = .connected
    // The host owns focus policy. Never retain it through this notification.
    weak var dispatchCoordinator: PreparedInputDispatchCoordinator?
    weak var readyObserver: ReadyObserver?
    weak var commandHandler: CommandHandler?
    weak var inputFailureObserver: InputFailureObserver? {
        didSet { scheduleInputFailureNotificationIfNeeded() }
    }
    private static let maximumInputFailureRecords = 16
    private var inputFailureRecords: [InputFailureRecord] = []
    private var inputFailureOverflowCount = 0
    private var inputFailureGeneration = UUID()
    private var recordedFailureGeneration = UUID()
    private var lastNotifiedInputFailureGeneration: UUID?
    private var inputFailureIdleWorkPending = false
    private var inputFailureDeliveryPending = false
    private var notifyingInputFailureObserver = false
    private var focusSuspended = false
    private var activated = false
    private var dispatchDepth = 0
    private var driverDepth = 0
    private var callbackDepth = 0
    private var inputActionGeneration = UUID()
    private struct PendingHistory {
        let id: UUID
        let operation: RunestoneInputHistoryOperation
        let revision: UUID
        let generation: UUID
    }
    private var pendingHistory: PendingHistory?
    private var historyDeliveryScheduled = false
    private var historyIdleWorkPending = false
    private var historyInFlight = false
    private var drainScheduled = false
    private var generation = UUID()
    private var deferredInvalidation = false
    private var wantsDisconnect = false
    private var wantsAbandon = false
    private var resetDuringReconstruction = false
    private var notifyingBlocked = false
    private var retryRequestedDuringBlocked = false
    private var gateReleaseDuringReconstruction = false
    private var blockedRetryGeneration = UUID()

    init?(adapter: PreparedInputEventAdapter, view: ReadOnlyDocumentView,
          initiallyFocusSuspended: Bool = false, makeDriver: DriverFactory? = nil,
          schedule: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
          blocked: @escaping () -> Void = {}) {
        precondition(Thread.isMainThread)
        guard adapter.ownsInputView(view), let token = adapter.claimInputContext() else { return nil }
        self.focusSuspended = initiallyFocusSuspended
        self.payload = Payload(adapter: adapter, view: view,
                               makeDriver: makeDriver ?? { AppKitPreparedDriver(client: $0) },
                               schedule: schedule, blocked: blocked, token: token)
        guard installDriver() else {
            precondition(adapter.releaseInputContext(token))
            self.contextToken = nil
            return nil
        }
    }

    private func installDriver() -> Bool {
        let client = PreparedContextClient()
        // The context may query attributes during initialization. An unattached
        // client returns inert values until its complete lifetime is established.
        let newDriver = makeDriver(client)
        guard objc_getAssociatedObject(newDriver.associationTarget, &preparedContextClientKey) == nil else { return false }
        objc_setAssociatedObject(newDriver.associationTarget, &preparedContextClientKey, client, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        client.owner = self
        textCheckingController = NSTextCheckingController(client: client)
        driver = newDriver
        proxy = client
        view.inputInvalidation.attach { [weak self] in self?.invalidateCoordinates() }
        return true
    }

    fileprivate var checksSpellingWhileTyping: Bool { view.displayConfiguration.checksSpellingWhileTyping }
    fileprivate var correctsSpellingAutomatically: Bool? { view.displayConfiguration.correctsSpellingAutomatically }

    var spellingAnnotationRects: [NSRect] {
        guard checksSpellingWhileTyping, isConnectedForEditing else { return [] }
        return textCheckingAnnotations.spellingRanges.flatMap {
            InputSelectionGeometry.geometry(selection: $0, marked: nil, in: view)?.selectionRects ?? []
        }
    }

    var nativeTextCheckingController: NSTextCheckingController? { textCheckingController }

    var spellingCorrectionRects: [NSRect] {
        guard isConnectedForEditing, let correction = spellingCorrection,
              correction.revision == adapter.installedRevisionForDispatch else { return [] }
        return InputSelectionGeometry.geometry(selection: correction.range, marked: nil, in: view)?.selectionRects ?? []
    }

    func dismissSpellingCorrection() {
        guard spellingCorrection != nil || spellingIndicatorID != nil else { return }
        spellingCorrection = nil
        dismissSpellingIndicator()
        view.needsDisplay = true
    }

    private func dismissSpellingIndicator() {
        guard spellingIndicatorID != nil else { return }
        spellingIndicatorID = nil
        NSSpellChecker.shared.dismissCorrectionIndicator(for: view)
    }

    func showSpellingReversion(at point: NSPoint) -> Bool {
        guard let correction = spellingCorrection,
              let rect = spellingCorrectionRects.first(where: { $0.contains(point) }) else { return false }
        if spellingIndicatorID != nil { return true }
        let id = UUID()
        spellingIndicatorID = id
        NSSpellChecker.shared.showCorrectionIndicator(of: .reversion, primaryString: correction.original,
                                                        alternativeStrings: [], forStringIn: rect, view: view) { [weak self] accepted in
            DispatchQueue.main.async {
                guard let self, self.spellingIndicatorID == id else { return }
                self.spellingIndicatorID = nil
                guard accepted == correction.original else { return }
                self.revertSpellingCorrection()
            }
        }
        view.needsDisplay = true
        return true
    }

    @discardableResult
    func revertSpellingCorrection() -> Bool {
        guard isConnectedForEditing, let correction = spellingCorrection,
              correction.revision == adapter.installedRevisionForDispatch,
              let controller = textCheckingController, let state = inputState(),
              state.selection.length == 0, state.selection.location >= NSMaxRange(correction.range) else { return false }
        let delta = correction.original.utf16.count - correction.range.length
        let edit = RunestoneHostEdit(replacementRange: correction.range, replacementText: correction.original,
                                     selectedRange: NSRange(location: state.selection.location + delta, length: 0))
        dismissSpellingCorrection()
        guard applyHostEdit(edit) else { return false }
        NSSpellChecker.shared.record(.reverted, toCorrection: correction.replacement, forWord: correction.original,
                                     language: correction.language, inSpellDocumentWithTag: controller.spellCheckerDocumentTag)
        controller.didChangeText(in: NSRange(location: correction.range.location, length: correction.original.utf16.count))
        controller.didChangeSelectedRange()
        return true
    }

    fileprivate func annotatedTextCheckingSubstring(_ proposed: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let snapshot = textFinderSnapshot() else { return nil }
        let text = snapshot.text as NSString
        guard let clamped = PreparedInputTextCheckingAnnotations.clamp(proposed, textLength: text.length) else { return nil }
        let range: NSRange
        if text.length == 0 { range = NSRange(location: 0, length: 0) }
        else {
            let probe = clamped.length == 0 ? NSRange(location: min(clamped.location, text.length - 1), length: 0) : clamped
            range = text.paragraphRange(for: probe)
        }
        actualRange?.pointee = range
        let result = NSMutableAttributedString(string: text.substring(with: range))
        textCheckingAnnotations.apply(to: result, documentRange: range)
        return result
    }

    fileprivate func setTextCheckingAnnotations(_ values: [NSAttributedString.Key: String], range: NSRange, adding: Bool) {
        guard let snapshot = textFinderSnapshot() else { return }
        let length = (snapshot.text as NSString).length
        if adding { textCheckingAnnotations.add(values, range: range, textLength: length) }
        else { textCheckingAnnotations.set(values, range: range, textLength: length) }
        if checksSpellingWhileTyping { view.needsDisplay = true }
    }

    fileprivate func removeTextCheckingAnnotation(_ key: NSAttributedString.Key, range: NSRange) {
        guard let snapshot = textFinderSnapshot() else { return }
        textCheckingAnnotations.remove(key, range: range, textLength: (snapshot.text as NSString).length)
        if checksSpellingWhileTyping { view.needsDisplay = true }
    }

    fileprivate func replaceTextCheckingRange(_ range: NSRange, with value: NSAttributedString) {
        guard replaceForTextFinder(range, with: value.string) else { return }
        textCheckingAnnotations.removeAll()
        textCheckingController?.didChangeText(in: range)
    }

    fileprivate func selectTextCheckingRange(_ range: NSRange) {
        guard setSelectionForTextFinder(range) else { return }
        textCheckingController?.didChangeSelectedRange()
    }

    fileprivate func textCheckingView(for range: NSRange, firstRect: NSRectPointer?, actualRange: NSRangePointer?) -> NSView? {
        guard let snapshot = textFinderSnapshot(),
              let clamped = PreparedInputTextCheckingAnnotations.clamp(range, textLength: (snapshot.text as NSString).length),
              let geometry = InputScreenRangeGeometry.firstRect(for: clamped, in: view) else { return nil }
        firstRect?.pointee = geometry.rect
        actualRange?.pointee = geometry.actualRange
        return view
    }

    fileprivate var documentVisibleRect: NSRect {
        query(.zero) { _ in
            guard let window = view.window else { return .zero }
            return window.convertToScreen(view.convert(view.visibleRect, to: nil))
        }
    }

    fileprivate var unionRectInVisibleSelectedRange: NSRect {
        query(.zero) { adapter in
            guard let window = view.window,
                  let selection = adapter.selectionStateForHost(),
                  let geometry = InputSelectionGeometry.geometry(selection: selection, marked: nil, in: view) else { return .zero }
            if var caret = geometry.caretRect {
                caret.size.width = 0
                return window.convertToScreen(view.convert(caret, to: nil))
            }
            let visible = view.visibleRect
            let union = geometry.selectionRects.reduce(CGRect.null) { result, rect in
                result.union(rect.intersection(visible))
            }
            guard !union.isEmpty else { return .zero }
            return window.convertToScreen(view.convert(union, to: nil))
        }
    }

    /// Only a responder that currently owns focus may expose this context.
    /// A previously retained context has an inert client after reset or blur.
    var currentInputContext: NSTextInputContext? {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired, let currentDriver = driver else { return nil }
        let expected = generation
        let context = currentDriver.inputContext
        guard state == .connected, !focusSuspended, !view.isRetired,
              generation == expected, driver === currentDriver else { return nil }
        return context
    }

    /// Immediately suppress a blurred client's callbacks. The old context is
    /// discarded only after all active callbacks and driver calls unwind.
    func suspendForFocusLoss() {
        precondition(Thread.isMainThread)
        guard !focusSuspended else { return }
        focusSuspended = true
        dismissSpellingCorrection()
        requestReset()
    }

    /// The host must verify its current focus generation and window ownership
    /// before each call, including from a ready notification. Returns false
    /// while reconstruction is pending; the weak observer is notified when ready.
    @discardableResult
    func resumeForFocus() -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, !view.isRetired, !historyInFlight, driverDepth == 0, callbackDepth == 0 else { return false }
        focusSuspended = false
        return activate()
    }

    @discardableResult
    func activate() -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired,
              !historyInFlight, driverDepth == 0, callbackDepth == 0, let driver = driver else { return false }
        if activated { return true }
        activated = true
        driverDepth += 1
        defer { finishDriverCall() }
        driver.activate()
        let isActive = state == .connected && !focusSuspended && !view.isRetired
        if isActive {
            view.scheduleAccessibilityValueChanged()
            view.scheduleAccessibilitySelectionChanged()
        }
        return isActive
    }

    /// The outer lease spans driver dispatch and key-binding fallback. A later
    /// out-of-band client callback starts a separate scope.
    @discardableResult
    func performCoordinatedInput(_ body: () -> Void) -> Bool {
        precondition(Thread.isMainThread)
        guard let coordinator = dispatchCoordinator else { body(); return true }
        // Do not let a later event overtake a queued or executing history action.
        if (pendingHistory != nil || historyInFlight) && !coordinator.isActive {
            coordinator.rejectDispatch(expectedRevision: adapter.installedRevisionForDispatch, reason: .busy)
            return false
        }
        let failureGeneration = recordedFailureGeneration
        let currentGeneration = generation
        dispatchDepth += 1
        defer { dispatchDepth -= 1; finishActivity() }
        return coordinator.perform(expectedRevision: adapter.installedRevisionForDispatch, body: {
            body()
            return self.recordedFailureGeneration == failureGeneration && self.generation == currentGeneration &&
                self.state == .connected && !self.view.isRetired &&
                coordinator.isCurrent(revision: self.adapter.installedRevisionForDispatch)
        }, isStillCurrent: {
            self.recordedFailureGeneration == failureGeneration && self.generation == currentGeneration &&
                self.state == .connected && !self.view.isRetired
        })
    }

    /// Synchronous input callouts recheck this after invoking outside code.
    var isActiveForInput: Bool {
        precondition(Thread.isMainThread)
        return state == .connected && !focusSuspended && !view.isRetired && activated &&
            pendingHistory == nil && !historyInFlight
    }

    /// Side-effect-free advisory validation; execution reacquires the gate.
    func canPerformHistory(_ operation: RunestoneInputHistoryOperation) -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired, activated,
              pendingHistory == nil, !historyInFlight, let coordinator = dispatchCoordinator,
              let revision = adapter.installedRevisionForDispatch,
              adapter.hasProvisionalCompositionForInput() == false else { return false }
        return coordinator.canPerformHistory(operation, expectedRevision: revision)
    }

    /// Queue one document-owned history action from an admitted input scope.
    /// The host will perform it only after that scope and all callbacks unwind.
    func requestHistory(_ operation: RunestoneInputHistoryOperation) {
        precondition(Thread.isMainThread)
        guard let coordinator = dispatchCoordinator else {
            recordInputFailure(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        let id = UUID()
        let expected = adapter.installedRevisionForDispatch
        guard coordinator.isActive, state == .connected, !focusSuspended, !view.isRetired,
              let revision = expected, adapter.hasProvisionalCompositionForInput() == false else {
            coordinator.rejectHistory(id: id, expectedRevision: expected, reason: .unavailable)
            recordInputFailure(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        guard pendingHistory == nil, !historyInFlight else {
            coordinator.rejectHistory(id: id, expectedRevision: revision, reason: .busy)
            recordInputFailure(operation: .command, failure: .init(reason: .busy, effect: .notApplied))
            return
        }
        pendingHistory = PendingHistory(id: id, operation: operation, revision: revision, generation: generation)
    }

    private func schedulePendingHistoryIfPossible() {
        guard pendingHistory != nil, !historyDeliveryScheduled, !historyIdleWorkPending, !historyInFlight,
              dispatchDepth == 0, driverDepth == 0, callbackDepth == 0 else { return }
        if adapter.inputActivityIsBusy {
            historyIdleWorkPending = true
            adapter.whenInputActivityIdle { [weak self] in
                guard let self = self else { return }
                self.historyIdleWorkPending = false
                self.schedule { [weak self] in self?.schedulePendingHistoryIfPossible() }
            }
            return
        }
        historyDeliveryScheduled = true
        schedule { [weak self] in
            guard let self = self else { return }
            self.historyDeliveryScheduled = false
            guard self.dispatchDepth == 0, self.driverDepth == 0, self.callbackDepth == 0 else { return }
            if self.adapter.inputActivityIsBusy { self.schedulePendingHistoryIfPossible(); return }
            self.deliverPendingHistory()
        }
    }

    private func deliverPendingHistory() {
        guard let pending = pendingHistory, let coordinator = dispatchCoordinator else { return }
        pendingHistory = nil
        guard state == .connected, !focusSuspended, !view.isRetired, !wantsDisconnect, !wantsAbandon,
              generation == pending.generation, let current = adapter.installedRevisionForDispatch else {
            coordinator.rejectHistory(id: pending.id, expectedRevision: pending.revision, reason: .unavailable)
            return
        }
        guard current == pending.revision else {
            coordinator.rejectHistory(id: pending.id, expectedRevision: pending.revision, reason: .stale)
            return
        }
        historyInFlight = true
        coordinator.performHistory(pending.operation, id: pending.id, expectedRevision: pending.revision) {
            !self.focusSuspended && !self.wantsDisconnect && !self.wantsAbandon && !self.view.isRetired
        }
        historyInFlight = false
        finishActivity()
    }

    /// An unavailable key was never passed to the input driver. A declined
    /// key was passed to AppKit and must never be replayed as an event.
    @discardableResult
    func dispatchKey(_ event: NSEvent) -> KeyDispatchOutcome {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired, activated,
              !historyInFlight, driverDepth == 0, callbackDepth == 0, let driver = driver else {
            let reason: PreparedInputEventAdapter.InputFailure.Reason =
                driverDepth != 0 || callbackDepth != 0 ? .reentrant : .unavailable
            recordInputFailure(operation: .undispatchedKey, failure: .init(reason: reason, effect: .notApplied))
            return .unavailable
        }
        let previousAction = inputActionGeneration
        let expectedGeneration = generation
        driverDepth += 1
        defer { finishDriverCall() }
        let handled = driver.handle(event)
        let receivedCallback = inputActionGeneration != previousAction
        let interrupted = state != .connected || focusSuspended || view.isRetired || !activated ||
            generation != expectedGeneration || self.driver !== driver
        if interrupted {
            // The input method has seen the event, so its effects are unknown.
            // This describes the interrupted dispatch and never permits replay.
            recordInputFailure(operation: .inputDispatchInterrupted,
                               failure: .init(reason: .unavailable, effect: .mayHaveApplied))
        }
        // Queries alone do not consume a key. Never repeat a callback as a
        // key-binding fallback even if the input driver reports false.
        return handled || receivedCallback || interrupted ? .handled : .declined
    }

    @discardableResult
    func handle(_ event: NSEvent) -> Bool { dispatchKey(event) == .handled }

    /// Keep the whole system key-binding interpreter call on the activity stack.
    /// The responder must check focus again before invoking this fallback.
    @discardableResult
    func performKeyBindingFallback(_ body: () -> Void) -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired, activated,
              !historyInFlight, driverDepth == 0, callbackDepth == 0 else {
            // AppKit may already have seen the event before fallback was
            // requested; do not infer that the whole event had no effects.
            recordInputFailure(operation: .keyBindingFallback,
                               failure: .init(reason: .unavailable, effect: .mayHaveApplied))
            return false
        }
        driverDepth += 1
        defer { finishDriverCall() }
        body()
        return true
    }

    /// Protects responder-side selection, hit testing and drawing callouts with
    /// the same quiescence guard as input callbacks. The responder must also
    /// verify window focus, particularly after any callout. The supplied check
    /// becomes false as soon as this connection resets, blurs or is retired.
    @discardableResult
    func performResponderActivity(_ body: (PreparedInputEventAdapter, () -> Bool) -> Void) -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired, activated,
              !historyInFlight, driverDepth == 0, callbackDepth == 0, let currentDriver = driver else { return false }
        let expected = generation
        callbackDepth += 1
        defer { callbackDepth -= 1; finishActivity() }
        let isCurrent = { [self] in
            state == .connected && !focusSuspended && !view.isRetired && activated &&
                generation == expected && driver === currentDriver
        }
        body(adapter, isCurrent)
        if adapter.needsInputReset { requestReset() }
        return isCurrent()
    }

    /// Used only by the responder's system key-binding callbacks.
    func insertTextFromKeyBinding(_ value: Any, replacementRange: NSRange) {
        insertCommittedText(value, replacementRange: replacementRange)
    }

    fileprivate func insertCommittedText(_ value: Any, replacementRange: NSRange) {
        let text = (value as? NSAttributedString)?.string ?? (value as? String) ?? ""
        let length = text.utf16.count
        let isWhitespace = text.unicodeScalars.count == 1 &&
            text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
        let isPunctuation = text.unicodeScalars.count == 1 &&
            text.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
        mutate(operation: .insertText) { adapter in
            dismissSpellingIndicator()
            let priorRevision = adapter.installedRevisionForDispatch
            let attempt = adapter.insertTextReporting(value, replacementRange: replacementRange)
            guard attempt.outcome == .processed, length > 0,
                  let caret = adapter.inputStateForHost()?.selection,
                  caret.length == 0, caret.location >= length else { return attempt }
            let range = NSRange(location: caret.location - length, length: length)
            let expectedGeneration = generation
            let expectedAction = inputActionGeneration
            let expectedRevision = adapter.installedRevisionForDispatch
            if var existing = spellingCorrection {
                if existing.revision == priorRevision, let expectedRevision,
                   replacementRange.location == NSNotFound, range.location >= NSMaxRange(existing.range) {
                    existing.revision = expectedRevision
                    spellingCorrection = existing
                } else {
                    dismissSpellingCorrection()
                }
            }
            // AppKit can synchronously ask the client to replace text. Wait until
            // the driver callback and the document's input reservation unwind.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == expectedGeneration,
                      self.inputActionGeneration == expectedAction, self.activated,
                      self.isConnectedForEditing,
                      self.adapter.installedRevisionForDispatch == expectedRevision else { return }
                self.textCheckingAnnotations.removeAll()
                self.textCheckingController?.didChangeText(in: range)
                if (isWhitespace || isPunctuation) && self.correctCompletedWord(
                    before: range.location, caret: caret.location, delimiter: text, allowsSpelling: isWhitespace
                ) { return }
                guard self.generation == expectedGeneration, self.inputActionGeneration == expectedAction,
                      self.adapter.installedRevisionForDispatch == expectedRevision else { return }
                self.textCheckingController?.insertedText(in: range)
                if self.checksSpellingWhileTyping {
                    self.textCheckingController?.considerTextChecking(for: range)
                }
            }
            return attempt
        }
    }

    private func correctCompletedWord(before end: Int, caret: Int, delimiter: String, allowsSpelling: Bool) -> Bool {
        let correctSpelling = allowsSpelling &&
            (correctsSpellingAutomatically ?? NSSpellChecker.isAutomaticSpellingCorrectionEnabled)
        let capitalize = NSSpellChecker.isAutomaticCapitalizationEnabled
        guard correctSpelling || capitalize, end > 0,
              let controller = textCheckingController, let revision = adapter.installedRevisionForDispatch,
              let state = inputState(), !state.hasComposition,
              state.selection == NSRange(location: caret, length: 0) else { return false }
        let action = inputActionGeneration
        let start = max(0, end - 256)
        let range = NSRange(location: start, length: end - start)
        guard let context = query(nil, { $0.attributedSubstringForInput(range: range, actualRange: nil) })?.string
        else { return false }

        var word: NSRange?
        (context as NSString).enumerateSubstrings(in: NSRange(location: 0, length: range.length),
                                                  options: [.byWords, .reverse, .substringNotRequired]) {
            _, wordRange, _, stop in
            if NSMaxRange(wordRange) == range.length && (start == 0 || wordRange.location > 0) { word = wordRange }
            stop.pointee = true
        }
        guard let word else { return false }
        let original = (context as NSString).substring(with: word)
        let checker = NSSpellChecker.shared
        let language = (checker.automaticallyIdentifiesLanguages
            ? checker.language(forWordRange: word, in: context, orthography: nil) : nil) ?? checker.language()
        let tag = controller.spellCheckerDocumentTag
        let types: NSTextCheckingResult.CheckingType = [.spelling, .correction]
        let options: [NSSpellChecker.OptionKey: Any] = [.automaticCapitalizationEnabledKey: capitalize]
        let replacementRange = NSRange(location: start + word.location, length: word.length)

        func finish(_ nativeCapitalization: String?) -> Bool {
            guard inputActionGeneration == action, isConnectedForEditing,
                  adapter.installedRevisionForDispatch == revision,
                  inputState()?.selection == state.selection else { return false }
            let spelling = nativeCapitalization == nil && correctSpelling
                ? checker.correction(forWordRange: word, in: context, language: language, inSpellDocumentWithTag: tag)
                : nil
            guard let correction = nativeCapitalization ?? spelling, correction != original,
                  inputActionGeneration == action, isConnectedForEditing,
                  adapter.installedRevisionForDispatch == revision,
                  inputState()?.selection == state.selection else { return false }
            return applyCompletedWordCorrection(correction, original: original, range: replacementRange,
                                                caret: caret, language: language, controller: controller)
        }

        guard capitalize else { return finish(nil) }
        // The delimiter is part of Apple's decision, for example when it interprets a period as an abbreviation.
        if let correction = checker.check(
            context + delimiter, range: word, types: types.rawValue, options: options,
            inSpellDocumentWithTag: tag, orthography: nil, wordCount: nil
        ).first(where: {
            $0.resultType == .correction && $0.range == word &&
                $0.replacementString?.caseInsensitiveCompare(original) == .orderedSame
        })?.replacementString {
            return finish(correction)
        }

        // AppKit supplies sentence-start casing through its top candidate. Accept only a
        // case-only change to the completed word, excluding the candidate's trailing space.
        let selectedRange = NSRange(location: range.length, length: 0)
        checker.requestCandidates(forSelectedRange: selectedRange, in: context, types: types.rawValue,
                                  options: options, inSpellDocumentWithTag: tag) { _, results in
            let first = results.first
            let candidate = first?.range == word
                ? first?.replacementString?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let capitalization = candidate.flatMap {
                $0 != original && $0.caseInsensitiveCompare(original) == .orderedSame ? $0 : nil
            }
            DispatchQueue.main.async {
                if !finish(capitalization), self.inputActionGeneration == action,
                   self.isConnectedForEditing, self.adapter.installedRevisionForDispatch == revision {
                    controller.insertedText(in: NSRange(location: end, length: delimiter.utf16.count))
                }
            }
        }
        if checksSpellingWhileTyping { controller.considerTextChecking(for: replacementRange) }
        return true
    }

    private func applyCompletedWordCorrection(_ correction: String, original: String, range: NSRange, caret: Int,
                                              language: String, controller: NSTextCheckingController) -> Bool {
        let edit = RunestoneHostEdit(
            replacementRange: range, replacementText: correction,
            selectedRange: NSRange(location: caret + correction.utf16.count - range.length, length: 0))
        guard applyHostEdit(edit) else { return false }
        dismissSpellingCorrection()
        let correctedRange = NSRange(location: edit.replacementRange.location, length: correction.utf16.count)
        if let revision = adapter.installedRevisionForDispatch {
            spellingCorrection = SpellingCorrection(range: correctedRange, original: original,
                                                    replacement: correction, language: language, revision: revision)
        }
        controller.didChangeText(in: correctedRange)
        controller.didChangeSelectedRange()
        return true
    }

    /// Used only by the responder's system key-binding callbacks.
    func doCommandFromKeyBinding(_ selector: Selector) {
        command(selector)
    }

    private func invalidateCoordinates() {
        guard state == .connected, !focusSuspended, !view.isRetired, activated else { return }
        guard !historyInFlight, dispatchDepth == 0, driverDepth == 0, callbackDepth == 0 else { deferredInvalidation = true; return }
        guard let driver = driver else { return }
        driverDepth += 1
        defer { finishDriverCall() }
        driver.invalidateCoordinates()
    }

    private func finishDriverCall() {
        driverDepth -= 1
        finishActivity()
    }

    private func finishActivity() {
        if !historyInFlight && dispatchDepth == 0 && driverDepth == 0 && callbackDepth == 0 { view.flushAccessibilityNotificationsIfNeeded() }
        if !historyInFlight && dispatchDepth == 0 && driverDepth == 0 && callbackDepth == 0 && deferredInvalidation && state == .connected {
            deferredInvalidation = false
            view.inputInvalidation.invalidate()
        }
        scheduleDrainIfNeeded()
        scheduleInputFailureNotificationIfNeeded()
        schedulePendingHistoryIfPossible()
    }

    /// Stores bounded metadata only; previous callbacks in the same AppKit
    /// event may already have changed the document.
    func recordInputFailure(operation: InputOperation, failure: PreparedInputEventAdapter.InputFailure) {
        precondition(Thread.isMainThread)
        if inputFailureRecords.count < Self.maximumInputFailureRecords {
            inputFailureRecords.append(InputFailureRecord(operation: operation, failure: failure))
        } else if inputFailureOverflowCount < Int.max {
            inputFailureOverflowCount += 1
        }
        inputFailureGeneration = UUID()
        recordedFailureGeneration = UUID()
        scheduleInputFailureNotificationIfNeeded()
    }

    /// Acknowledges the batch. No typed value or event is retained or retried.
    func takeInputFailures() -> InputFailureBatch {
        precondition(Thread.isMainThread)
        let batch = InputFailureBatch(records: inputFailureRecords, overflowCount: inputFailureOverflowCount)
        inputFailureRecords.removeAll(keepingCapacity: true)
        inputFailureOverflowCount = 0
        inputFailureGeneration = UUID()
        return batch
    }

    private func scheduleInputFailureNotificationIfNeeded() {
        precondition(Thread.isMainThread)
        guard !inputFailureRecords.isEmpty || inputFailureOverflowCount > 0 else { return }
        guard inputFailureObserver != nil, inputFailureGeneration != lastNotifiedInputFailureGeneration,
              !historyInFlight, dispatchDepth == 0, driverDepth == 0, callbackDepth == 0, !inputFailureIdleWorkPending,
              !inputFailureDeliveryPending, !notifyingInputFailureObserver else { return }
        inputFailureIdleWorkPending = true
        adapter.whenInputActivityIdle { [weak self] in
            guard let self = self else { return }
            self.inputFailureIdleWorkPending = false
            guard !self.inputFailureRecords.isEmpty || self.inputFailureOverflowCount > 0,
                  self.inputFailureObserver != nil,
                  self.inputFailureGeneration != self.lastNotifiedInputFailureGeneration,
                  !self.historyInFlight, self.dispatchDepth == 0, self.driverDepth == 0, self.callbackDepth == 0 else { return }
            // The adapter is still in its idle guard. A later callback must
            // recheck all activity; a queued turn is not proof of quiescence.
            self.inputFailureDeliveryPending = true
            self.schedule { [weak self] in self?.deliverInputFailureNotification() }
        }
    }

    private func deliverInputFailureNotification() {
        precondition(Thread.isMainThread)
        inputFailureDeliveryPending = false
        guard !inputFailureRecords.isEmpty || inputFailureOverflowCount > 0,
              let observer = inputFailureObserver,
              inputFailureGeneration != lastNotifiedInputFailureGeneration else { return }
        guard !historyInFlight, dispatchDepth == 0, driverDepth == 0, callbackDepth == 0 else { return }
        if adapter.inputActivityIsBusy {
            scheduleInputFailureNotificationIfNeeded()
            return
        }
        lastNotifiedInputFailureGeneration = inputFailureGeneration
        notifyingInputFailureObserver = true
        observer.preparedInputContextConnectionHasInputFailures(self)
        notifyingInputFailureObserver = false
        scheduleInputFailureNotificationIfNeeded()
    }

    fileprivate func query<T>(_ fallback: T, _ action: (PreparedInputEventAdapter) -> T) -> T {
        precondition(Thread.isMainThread)
        guard state == .connected, !focusSuspended, !view.isRetired, !historyInFlight else { return fallback }
        callbackDepth += 1
        defer { callbackDepth -= 1; finishActivity() }
        let result = action(adapter)
        if adapter.needsInputReset { requestReset() }
        return state == .connected && !focusSuspended && !view.isRetired ? result : fallback
    }

    /// Focus eligibility is separate from activation: a newly attached view
    /// must be eligible before its host explicitly asks the window to focus it.
    var isConnectedForEditing: Bool {
        precondition(Thread.isMainThread)
        return state == .connected && !view.isRetired && !adapter.needsInputReset &&
            pendingHistory == nil && !historyInFlight
    }

    /// A single revision-checked query preserves the relationship between the
    /// selection, marked range and an empty provisional composition.
    func inputState() -> (selection: NSRange, selectionState: InputSelectionState,
                          marked: NSRange?, hasComposition: Bool)? {
        precondition(Thread.isMainThread)
        guard activated else { return nil }
        return query(nil) { $0.inputStateForHost() }
    }

    /// Text and range are captured together against the installed revision.
    func selectionSnapshot() -> (state: InputSelectionState, text: String)? {
        precondition(Thread.isMainThread)
        guard activated else { return nil }
        return query(nil) { $0.selectionSnapshotForHost() }
    }

    func textFinderSnapshot() -> (text: String, selection: NSRange)? {
        precondition(Thread.isMainThread)
        guard activated else { return nil }
        return query(nil) { $0.textFinderSnapshotForHost() }
    }

    /// Host-owned find actions use the same dispatch reservation and failure
    /// accounting as accessibility and responder mutations. A failed attempt
    /// is never replayed by the framework.
    func setSelectionForTextFinder(_ range: NSRange) -> Bool {
        performTextFinderMutation(operation: .setSelection) { $0.setSelectionReporting(range) }
    }

    func replaceForTextFinder(_ range: NSRange, with string: String) -> Bool {
        performTextFinderMutation(operation: .insertText) {
            $0.insertTextReporting(string, replacementRange: range)
        }
    }

    func applyHostEdit(_ edit: RunestoneHostEdit) -> Bool {
        performTextFinderMutation(operation: .insertText) {
            $0.applyHostEditReporting(edit)
        }
    }

    private func performTextFinderMutation(
        operation: InputOperation,
        _ action: @escaping (PreparedInputEventAdapter) -> PreparedInputEventAdapter.InputAttempt
    ) -> Bool {
        precondition(Thread.isMainThread)
        guard activated else { return false }
        var applied = false
        let admitted = performCoordinatedInput {
            self.mutate(operation: operation) { adapter in
                let attempt = action(adapter)
                applied = attempt.outcome == .processed
                return attempt
            }
        }
        return admitted && applied
    }

    /// Accessibility must not inspect a stale or suppressed input client.
    func accessibilityTextState() -> ReadOnlyDocumentView.AccessibilityTextState? {
        guard activated else { return nil }
        return query(nil) { $0.accessibilityTextStateForInput() }
    }

    fileprivate func mutate(operation: InputOperation,
                            _ action: (PreparedInputEventAdapter) -> PreparedInputEventAdapter.InputAttempt) {
        precondition(Thread.isMainThread)
        if let coordinator = dispatchCoordinator, !coordinator.isActive {
            _ = performCoordinatedInput { self.mutate(operation: operation, action) }
            return
        }
        inputActionGeneration = UUID()
        // No later callback in the same driver dispatch may pass a pending
        // history operation; reject it rather than reorder or replay it.
        guard pendingHistory == nil, !historyInFlight else {
            recordInputFailure(operation: operation, failure: .init(reason: .busy, effect: .notApplied))
            return
        }
        guard state == .connected, !focusSuspended, !view.isRetired else {
            recordInputFailure(operation: operation, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        callbackDepth += 1
        defer { callbackDepth -= 1; finishActivity() }
        let attempt = action(adapter)
        if let failure = attempt.failure { recordInputFailure(operation: operation, failure: failure) }
        if attempt.outcome != .processed { requestReset() }
    }

    fileprivate func command(_ selector: Selector) {
        precondition(Thread.isMainThread)
        if let coordinator = dispatchCoordinator, !coordinator.isActive {
            _ = performCoordinatedInput { self.command(selector) }
            return
        }
        inputActionGeneration = UUID()
        guard pendingHistory == nil, !historyInFlight else {
            recordInputFailure(operation: .command, failure: .init(reason: .busy, effect: .notApplied))
            return
        }
        guard state == .connected, !focusSuspended, !view.isRetired else {
            recordInputFailure(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        callbackDepth += 1
        defer { callbackDepth -= 1; finishActivity() }
        guard let handler = commandHandler else {
            recordInputFailure(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
            return
        }
        dismissSpellingCorrection()
        handler.preparedInputContextConnection(self, doCommand: selector)
    }

    /// Suppress callbacks immediately, but never discard on the triggering stack.
    func requestReset() {
        precondition(Thread.isMainThread)
        if state == .reconstructing { resetDuringReconstruction = true; return }
        guard state == .connected else { return }
        state = .resetRequested
        generation = UUID()
        scheduleDrainIfNeeded()
    }

    private func scheduleDrainIfNeeded() {
        guard state == .resetRequested, !drainScheduled else { return }
        drainScheduled = true
        let expected = generation
        schedule { [weak self] in
            guard let self = self, self.generation == expected else { return }
            self.drainScheduled = false
            self.drainReset()
        }
    }

    private func drainReset() {
        guard state == .resetRequested, !historyInFlight, dispatchDepth == 0, driverDepth == 0, callbackDepth == 0,
              driver != nil, contextToken != nil else { return }
        state = .quiescing
        view.inputInvalidation.detach()
        // Disarm before waiting: even nested AppKit callbacks are now inert.
        proxy?.owner = nil
        let expected = generation
        adapter.whenInputActivityIdle { [weak self] in
            guard let self = self, self.state == .quiescing, self.generation == expected,
                  let driver = self.driver, let token = self.contextToken else { return }
            if self.adapter.hasProvisionalCompositionForRetirement {
                self.dispatchCoordinator?.reportCompositionDiscarded()
                self.recordInputFailure(operation: .compositionDiscarded,
                                        failure: .init(reason: .compositionDiscarded, effect: .mayHaveApplied))
            }
            self.driverDepth += 1
            driver.discardMarkedText()
            if self.activated { driver.deactivate() }
            self.driverDepth -= 1
            self.driver = nil
            self.proxy = nil
            self.activated = false
            precondition(self.adapter.releaseInputContext(token))
            self.contextToken = nil
            self.state = .waiting
            // The adapter's idle-work guard must unwind before reconstruction.
            self.schedule { [weak self] in
                guard let self = self, self.generation == expected else { return }
                self.resumeAfterQuiescing()
            }
        }
    }

    /// Call after an actual document-gate release or stale snapshot becoming
    /// ready. The host must send a new signal for every later gate release; a
    /// blocked callback is an advisory notification, not a polling mechanism.
    func resumeAfterQuiescing() {
        resumeAfterQuiescing(isBlockedRetry: false)
    }

    /// A real gate release may arrive in a nested event loop while a previous
    /// reconstruction still has callouts on the stack. Preserve that wakeup.
    func documentGateDidBecomeAvailable() {
        precondition(Thread.isMainThread)
        if state == .reconstructing {
            gateReleaseDuringReconstruction = true
            return
        }
        resumeAfterQuiescing()
    }

    private func resumeAfterQuiescing(isBlockedRetry: Bool) {
        precondition(Thread.isMainThread)
        guard state == .waiting else { return }
        if notifyingBlocked {
            retryRequestedDuringBlocked = true
            return
        }
        // A newer attempt supersedes any previously queued readiness signal.
        blockedRetryGeneration = UUID()
        if wantsAbandon {
            finishAbandonment()
            return
        }
        state = .reconstructing
        resetDuringReconstruction = false
        gateReleaseDuringReconstruction = false
        let reconstruction = adapter.reconstructWithoutInputContext()
        if wantsAbandon {
            state = .waiting
            finishAbandonment()
            return
        }
        switch reconstruction {
        case .processed:
            break
        case .resetRequired:
            notifyBlocked(suppressRetry: isBlockedRetry)
            return
        case .unavailable:
            guard adapter.inputActivityIsBusy else { notifyBlocked(suppressRetry: isBlockedRetry); return }
            // A nested run loop can deliver the scheduled resume while the
            // adapter's idle cleanup is still unwinding. Retry only after its
            // activity guard becomes idle, rather than treating a queued turn
            // as proof that cleanup completed.
            state = .waiting
            let expected = generation
            adapter.whenInputActivityIdle { [weak self] in
                guard let self = self, self.state == .waiting, self.generation == expected else { return }
                self.schedule { [weak self] in
                    guard let self = self, self.generation == expected else { return }
                    self.resumeAfterQuiescing()
                }
            }
            return
        }
        if wantsDisconnect {
            guard adapter.disconnectAfterQuiescing() else { notifyBlocked(suppressRetry: isBlockedRetry); return }
            state = .disconnected
            return
        }
        guard let token = adapter.claimInputContext() else { notifyBlocked(suppressRetry: isBlockedRetry); return }
        contextToken = token
        guard installDriver() else {
            precondition(adapter.releaseInputContext(token))
            contextToken = nil
            notifyBlocked(suppressRetry: isBlockedRetry)
            return
        }
        state = .connected
        // Driver construction and revision checks may call out and request a
        // close or a newer reset. Do not lose either intent on installation.
        if wantsAbandon { abandonDocument(); return }
        if wantsDisconnect { _ = disconnect(); return }
        if resetDuringReconstruction { requestReset(); return }
        // The host must recheck current focus before exposing or activating it.
        readyObserver?.preparedInputContextConnectionDidBecomeReady(self)
    }

    private func notifyBlocked(suppressRetry: Bool) {
        state = .waiting
        if wantsAbandon { finishAbandonment(); return }
        let receivedGateRelease = gateReleaseDuringReconstruction
        gateReleaseDuringReconstruction = false
        retryRequestedDuringBlocked = false
        if !suppressRetry {
            notifyingBlocked = true
            blocked()
            notifyingBlocked = false
        }
        guard receivedGateRelease || retryRequestedDuringBlocked else { return }
        retryRequestedDuringBlocked = false
        let expected = generation
        let retry = UUID()
        blockedRetryGeneration = retry
        schedule { [weak self] in
            guard let self = self, self.generation == expected,
                  self.blockedRetryGeneration == retry else { return }
            // A newly observed gate release may warrant one more attempt.
            // An advisory blocked callback alone cannot cause polling.
            self.resumeAfterQuiescing(isBlockedRetry: true)
        }
    }

    /// A lost or invalidated document permanently retires this view. Quiesce
    /// the old context but do not ask a missing or busy document to reconstruct.
    func abandonDocument() {
        precondition(Thread.isMainThread)
        view.quarantineInputViewWithoutCallouts()
        wantsAbandon = true
        switch state {
        case .connected:
            requestReset()
        case .resetRequested:
            scheduleDrainIfNeeded()
        case .waiting:
            finishAbandonment()
        case .quiescing, .reconstructing, .disconnected:
            break
        }
    }

    private func finishAbandonment() {
        guard state == .waiting, wantsAbandon else { return }
        if adapter.retireAfterQuiescing() {
            state = .disconnected
            return
        }
        guard adapter.inputActivityIsBusy else { return }
        let expected = generation
        adapter.whenInputActivityIdle { [weak self] in
            guard let self = self, self.state == .waiting, self.generation == expected,
                  self.wantsAbandon else { return }
            self.schedule { [weak self] in
                guard let self = self, self.generation == expected else { return }
                self.finishAbandonment()
            }
        }
    }

    var isDisconnected: Bool { state == .disconnected }

    /// A close intent survives callbacks, reset, and a temporarily busy document.
    /// Returns true only after reconstruction and disconnection have completed.
    @discardableResult
    func disconnect() -> Bool {
        precondition(Thread.isMainThread)
        if state == .disconnected { return true }
        wantsDisconnect = true
        switch state {
        case .connected:
            state = .resetRequested
            generation = UUID()
            if !historyInFlight && dispatchDepth == 0 && driverDepth == 0 && callbackDepth == 0 { drainReset() }
            else { scheduleDrainIfNeeded() }
        case .resetRequested:
            scheduleDrainIfNeeded()
        case .waiting:
            resumeAfterQuiescing()
        case .quiescing, .reconstructing, .disconnected:
            break
        }
        return state == .disconnected
    }

    deinit {
        // Stored properties are released after deinit returns. Move all
        // AppKit-owning references out before unlocking the main-queue block,
        // so it cannot release the last reference on the wrong thread.
        let gate = NSLock()
        gate.lock()
        transferCleanupToMain(gate: gate)
        gate.unlock()
    }

    private func transferCleanupToMain(gate: NSLock) {
        guard let payload = payload else { return }
        self.payload = nil
        let shouldRetire = state != .disconnected
        let wasActivated = activated
        let abandonedHistory = pendingHistory
        let coordinator = dispatchCoordinator
        pendingHistory = nil
        if shouldRetire { payload.view.quarantineInputViewWithoutCallouts() }
        DispatchQueue.main.async {
            gate.lock()
            gate.unlock()
            if let pending = abandonedHistory {
                coordinator?.rejectHistory(id: pending.id, expectedRevision: pending.revision, reason: .unavailable)
            }
            guard shouldRetire else { withExtendedLifetime(payload) {}; return }
            payload.adapter.whenInputActivityIdle {
                payload.view.inputInvalidation.detach()
                payload.driver?.discardMarkedText()
                if wasActivated { payload.driver?.deactivate() }
                if let token = payload.contextToken { _ = payload.adapter.releaseInputContext(token) }
                withExtendedLifetime(payload.proxy) {}
            }
        }
    }

}

extension PreparedInputContextConnection.Driver {
    var inputContext: NSTextInputContext? { nil }
}

private var preparedContextClientKey: UInt8 = 0

/// The associated proxy never owns its context, adapter, view, or coordinator.
private final class PreparedContextClient: NSObject, NSTextCheckingClient {
    weak var owner: PreparedInputContextConnection?
    var autocorrectionType: NSTextInputTraitType {
        get { owner?.correctsSpellingAutomatically.map { $0 ? .yes : .no } ?? .default }
        set {}
    }
    var spellCheckingType: NSTextInputTraitType {
        get { owner?.checksSpellingWhileTyping == true ? .yes : .no }
        set {}
    }
    var grammarCheckingType: NSTextInputTraitType = .yes
    var smartQuotesType: NSTextInputTraitType = .default
    var smartDashesType: NSTextInputTraitType = .default
    var smartInsertDeleteType: NSTextInputTraitType = .default
    var textReplacementType: NSTextInputTraitType = .default
    var textCompletionType: NSTextInputTraitType = .yes
    var writingToolsBehavior: NSWritingToolsBehavior = .limited
    var allowedWritingToolsResultOptions: NSWritingToolsResultOptions = .plainText
    func insertText(_ string: Any, replacementRange: NSRange) {
        owner?.insertCommittedText(string, replacementRange: replacementRange)
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        owner?.mutate(operation: .setMarkedText) { $0.setMarkedTextReporting(string, selectedRange: selectedRange, replacementRange: replacementRange) }
    }
    func unmarkText() { owner?.mutate(operation: .unmarkText) { $0.unmarkTextReporting() } }
    func doCommand(by selector: Selector) { owner?.command(selector) }
    func selectedRange() -> NSRange {
        owner?.query(NSRange(location: NSNotFound, length: 0)) { $0.selectedRangeForInput() }
            ?? NSRange(location: NSNotFound, length: 0)
    }
    func markedRange() -> NSRange {
        owner?.query(NSRange(location: NSNotFound, length: 0)) { $0.markedRangeForInput() }
            ?? NSRange(location: NSNotFound, length: 0)
    }
    var documentVisibleRect: NSRect { owner?.documentVisibleRect ?? .zero }
    var unionRectInVisibleSelectedRange: NSRect { owner?.unionRectInVisibleSelectedRange ?? .zero }
    func hasMarkedText() -> Bool { markedRange().location != NSNotFound }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        var actual = NSRange(location: NSNotFound, length: 0)
        guard let result = owner?.query(nil, { $0.attributedSubstringForInput(range: range, actualRange: &actual) }) else { return nil }
        actualRange?.pointee = actual
        return result
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        let result: (NSRect, NSRange)? = owner?.query(nil) { adapter in
            var actual = NSRange(location: NSNotFound, length: 0)
            let rect = adapter.firstRectForInput(range: range, actualRange: &actual)
            return actual.location == NSNotFound ? nil : (rect, actual)
        }
        guard let result = result else { return .zero }
        actualRange?.pointee = result.1
        return result.0
    }
    func characterIndex(for point: NSPoint) -> Int {
        owner?.query(NSNotFound) { $0.characterIndexForInput(point: point) } ?? NSNotFound
    }
    func annotatedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        owner?.annotatedTextCheckingSubstring(range, actualRange: actualRange)
    }
    func setAnnotations(_ annotations: [NSAttributedString.Key: String], range: NSRange) {
        owner?.setTextCheckingAnnotations(annotations, range: range, adding: false)
    }
    func addAnnotations(_ annotations: [NSAttributedString.Key: String], range: NSRange) {
        owner?.setTextCheckingAnnotations(annotations, range: range, adding: true)
    }
    func removeAnnotation(_ annotationName: NSAttributedString.Key, range: NSRange) {
        owner?.removeTextCheckingAnnotation(annotationName, range: range)
    }
    func replaceCharacters(in range: NSRange, withAnnotatedString annotatedString: NSAttributedString) {
        owner?.replaceTextCheckingRange(range, with: annotatedString)
    }
    func selectAndShow(_ range: NSRange) { owner?.selectTextCheckingRange(range) }
    func view(for range: NSRange, firstRect: NSRectPointer?, actualRange: NSRangePointer?) -> NSView? {
        owner?.textCheckingView(for: range, firstRect: firstRect, actualRange: actualRange)
    }
    func candidateListTouchBarItem() -> NSCandidateListTouchBarItem<AnyObject>? { nil }
}

private final class AppKitPreparedDriver: PreparedInputContextConnection.Driver {
    private let context: NSTextInputContext
    init(client: NSTextInputClient) { context = NSTextInputContext(client: client) }
    var associationTarget: NSObject { context }
    var inputContext: NSTextInputContext? { context }
    func activate() { context.activate() }
    func handle(_ event: NSEvent) -> Bool { context.handleEvent(event) }
    func invalidateCoordinates() { context.invalidateCharacterCoordinates() }
    func discardMarkedText() { context.discardMarkedText() }
    func deactivate() { context.deactivate() }
}
#endif
