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
        driver = newDriver
        proxy = client
        view.inputInvalidation.attach { [weak self] in self?.invalidateCoordinates() }
        return true
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
        mutate(operation: .insertText) { $0.insertTextReporting(value, replacementRange: replacementRange) }
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
    func inputState() -> (selection: NSRange, marked: NSRange?, hasComposition: Bool)? {
        precondition(Thread.isMainThread)
        guard activated else { return nil }
        return query(nil) { $0.inputStateForHost() }
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
private final class PreparedContextClient: NSObject, NSTextInputClient {
    weak var owner: PreparedInputContextConnection?
    func insertText(_ string: Any, replacementRange: NSRange) {
        owner?.mutate(operation: .insertText) { $0.insertTextReporting(string, replacementRange: replacementRange) }
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
