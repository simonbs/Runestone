#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// Event-scoped document ownership for a prepared input session. This is not
/// an NSTextInputClient or an editor and must not be exposed as one.
/// A host must quiesce/discard the context when reset is requested and before
/// replacing the session. All operations and closures run on the main thread.
/// The owner must retain the adapter through reset and explicitly disconnect it;
/// injected closures must not retain the adapter or create an ownership cycle.
final class PreparedInputEventAdapter {
    final class Reservation {
        let prepare: (NSAttributedString) -> DocumentInputSession.PreparedChange?
        /// Finishes or cancels the event and releases its document-wide gate.
        /// Must be synchronous and called once, after all session callbacks.
        let close: () -> Void
        init(prepare: @escaping (NSAttributedString) -> DocumentInputSession.PreparedChange?,
             close: @escaping () -> Void) {
            self.prepare = prepare
            self.close = close
        }
    }

    /// A snapshot captured together with its revision while the document gate
    /// is held. close releases that gate after reconstruction has completed.
    final class ReconstructionReservation {
        let snapshot: NSAttributedString
        let revision: UUID
        let close: () -> Void
        init(snapshot: NSAttributedString, revision: UUID, close: @escaping () -> Void) {
            self.snapshot = NSAttributedString(attributedString: snapshot)
            self.revision = revision
            self.close = close
        }
    }

    final class InputContextToken { fileprivate init() {} }

    enum ReconstructionStart {
        case reserved(ReconstructionReservation)
        case busy
    }

    enum Outcome: Equatable {
        case processed
        // State may already have been published. Never retry this event.
        case resetRequired
        case unavailable
    }

    /// Describes one attempted input operation; failure is nil only on success.
    /// Only `.notApplied` proves this particular callback did not enter the
    /// session. It is not permission to replay an input-method event.
    struct InputFailure: Equatable {
        enum Reason: Equatable {
            case busy, stale, reentrant, unavailable, admittedFailure
            case unsupported, compositionActive, compositionDiscarded, invalidSelection
        }
        enum Effect: Equatable { case notApplied, mayHaveApplied }
        let reason: Reason
        let effect: Effect

        init(reason: Reason, effect: Effect) {
            self.reason = reason
            self.effect = effect
        }
    }

    struct InputAttempt: Equatable {
        let outcome: Outcome
        let failure: InputFailure?

        init(outcome: Outcome, failure: InputFailure?) {
            precondition((outcome == .processed) == (failure == nil))
            self.outcome = outcome
            self.failure = failure
        }
    }

    enum ReservationResult {
        case reserved(Reservation)
        case stale
        case busy
    }
    typealias BeginEvent = (UUID) -> ReservationResult
    private enum State { case ready, handling, resetPending, disconnected }

    // All potentially AppKit-owning references are transferred together on
    // deinit, before the main queue is allowed to release the payload.
    private final class Payload {
        let view: ReadOnlyDocumentView
        let permit: ReadOnlyDocumentView.InputMutationPermit
        let beginEvent: BeginEvent
        let beginReconstruction: () -> ReconstructionStart
        let documentRevision: () -> UUID?
        let typingAttributes: () -> [NSAttributedString.Key: Any]
        let requestReset: () -> Void
        let rectProvider: (NSRange, ReadOnlyDocumentView) -> InputScreenRangeGeometry.RangeGeometry?
        let indexProvider: (NSPoint, ReadOnlyDocumentView) -> Int?
        let schedule: (@escaping () -> Void) -> Void
        var session: DocumentInputSession?
        var reservation: Reservation?
        var idleWork: [() -> Void] = []

        init(view: ReadOnlyDocumentView, permit: ReadOnlyDocumentView.InputMutationPermit,
             beginEvent: @escaping BeginEvent, beginReconstruction: @escaping () -> ReconstructionStart,
             documentRevision: @escaping () -> UUID?, typingAttributes: @escaping () -> [NSAttributedString.Key: Any],
             requestReset: @escaping () -> Void,
             rectProvider: @escaping (NSRange, ReadOnlyDocumentView) -> InputScreenRangeGeometry.RangeGeometry?,
             indexProvider: @escaping (NSPoint, ReadOnlyDocumentView) -> Int?,
             schedule: @escaping (@escaping () -> Void) -> Void) {
            self.view = view
            self.permit = permit
            self.beginEvent = beginEvent
            self.beginReconstruction = beginReconstruction
            self.documentRevision = documentRevision
            self.typingAttributes = typingAttributes
            self.requestReset = requestReset
            self.rectProvider = rectProvider
            self.indexProvider = indexProvider
            self.schedule = schedule
        }
    }
    private var payload: Payload?
    private var view: ReadOnlyDocumentView { payload!.view }
    private var permit: ReadOnlyDocumentView.InputMutationPermit { payload!.permit }
    private var beginEvent: BeginEvent { payload!.beginEvent }
    private var beginReconstruction: () -> ReconstructionStart { payload!.beginReconstruction }
    private var documentRevision: () -> UUID? { payload!.documentRevision }
    private var typingAttributes: () -> [NSAttributedString.Key: Any] { payload!.typingAttributes }
    private var requestReset: () -> Void { payload!.requestReset }
    private var rectProvider: (NSRange, ReadOnlyDocumentView) -> InputScreenRangeGeometry.RangeGeometry? { payload!.rectProvider }
    private var indexProvider: (NSPoint, ReadOnlyDocumentView) -> Int? { payload!.indexProvider }
    // Scheduler must enqueue asynchronously, without an inline call or nested event loop.
    private var schedule: (@escaping () -> Void) -> Void { payload!.schedule }
    private var reservation: Reservation? {
        get { payload!.reservation }
        set { payload!.reservation = newValue }
    }
    private var pendingInputActivityIdleWork: [() -> Void] {
        get { payload!.idleWork }
        set { payload!.idleWork = newValue }
    }
    private var session: DocumentInputSession! {
        get { payload!.session }
        set { payload!.session = newValue }
    }
    private var state: State = .ready
    private var nestedMutationRejected = false
    private var queryDepth = 0
    private var queryNeedsReset = false
    // Covers revision callouts made while acquiring or releasing lifecycle ownership.
    private var lifecycleOperationInFlight = false
    private var inputContextToken: InputContextToken?
    private var pendingInputContextRelease: InputContextToken?
    private var inputContextReleaseScheduled = false
    private var inputActivityIdleDrainScheduled = false
    private var drainingInputActivityIdleWork = false
    private var resetGeneration = UUID()
    private var ownsPermit = true

    /// The caller has already captured the view content and revision together
    /// under the document gate, with no live input context using this view.
    init?(view: ReadOnlyDocumentView, snapshot: NSAttributedString, initialRevision: UUID,
          documentRevision: @escaping () -> UUID?,
          typingAttributes: @escaping () -> [NSAttributedString.Key: Any],
          beginEvent: @escaping BeginEvent,
          beginReconstruction: @escaping () -> ReconstructionStart,
          requestReset: @escaping () -> Void,
          rectProvider: @escaping (NSRange, ReadOnlyDocumentView) -> InputScreenRangeGeometry.RangeGeometry? = { InputScreenRangeGeometry.firstRect(for: $0, in: $1) },
          indexProvider: @escaping (NSPoint, ReadOnlyDocumentView) -> Int? = { InputScreenRangeGeometry.characterIndex(for: $0, in: $1) },
          schedule: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        precondition(Thread.isMainThread)
        let viewRevision = view.contentRevision
        guard documentRevision() == initialRevision, let permit = view.claimInputMutation() else { return nil }
        guard view.content.isEqual(to: snapshot), view.contentRevision == viewRevision,
              documentRevision() == initialRevision else {
            precondition(view.releaseInputMutation(permit))
            return nil
        }
        self.payload = Payload(view: view, permit: permit, beginEvent: beginEvent,
                               beginReconstruction: beginReconstruction, documentRevision: documentRevision,
                               typingAttributes: typingAttributes, requestReset: requestReset,
                               rectProvider: rectProvider, indexProvider: indexProvider, schedule: schedule)
        self.session = DocumentInputSession(view: view, mutationPermit: permit,
                                            prepareChange: { [weak self] candidate in
                                                guard let self = self, !self.nestedMutationRejected,
                                                      let result = self.reservation?.prepare(candidate),
                                                      !self.nestedMutationRejected else { return nil }
                                                return result
                                            }, compositionAttributes: typingAttributes,
                                            initialDocumentRevision: initialRevision,
                                            documentRevision: documentRevision)
    }

    /// The installed identity, only while a new dispatch may be admitted.
    var installedRevisionForDispatch: UUID? {
        precondition(Thread.isMainThread)
        guard state == .ready, !lifecycleOperationInFlight, !drainingInputActivityIdleWork,
              queryDepth == 0, !view.isRetired, !session.isStale,
              !session.hasDocumentConflict else { return nil }
        return session.installedRevisionForInput
    }

    var needsInputReset: Bool {
        precondition(Thread.isMainThread)
        return state == .resetPending
    }

    func ownsInputView(_ candidate: ReadOnlyDocumentView) -> Bool {
        precondition(Thread.isMainThread)
        return view === candidate
    }

    /// A context keeps this identity until its client and driver are quiescent.
    func claimInputContext() -> InputContextToken? {
        precondition(Thread.isMainThread)
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork, state == .ready,
              queryDepth == 0, inputContextToken == nil, !view.isRetired,
              !session.isStale, !session.hasDocumentConflict,
              let revision = session.installedRevisionForInput else { return nil }
        lifecycleOperationInFlight = true
        defer { finishLifecycleOperation() }
        guard documentRevision() == revision, !view.isRetired else { return nil }
        let token = InputContextToken()
        inputContextToken = token
        return token
    }

    @discardableResult
    func releaseInputContext(_ token: InputContextToken) -> Bool {
        precondition(Thread.isMainThread)
        guard !lifecycleOperationInFlight, state != .handling, queryDepth == 0,
              inputContextToken === token else { return false }
        inputContextToken = nil
        if pendingInputContextRelease === token { pendingInputContextRelease = nil }
        return true
    }

    /// Unexpected context teardown may happen in a nested event loop. Release
    /// only after the current adapter operation and query stack have unwound.
    @discardableResult
    func releaseInputContextWhenIdle(_ token: InputContextToken) -> Bool {
        precondition(Thread.isMainThread)
        guard inputContextToken === token else { return false }
        pendingInputContextRelease = token
        schedulePendingInputContextReleaseIfIdle()
        return true
    }

    private func schedulePendingInputContextReleaseIfIdle() {
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork, state != .handling, queryDepth == 0, !inputContextReleaseScheduled,
              let token = pendingInputContextRelease else { return }
        inputContextReleaseScheduled = true
        schedule { [weak self] in
            guard let self = self else { return }
            self.inputContextReleaseScheduled = false
            if !self.lifecycleOperationInFlight, !self.drainingInputActivityIdleWork, self.state != .handling, self.queryDepth == 0,
               self.pendingInputContextRelease === token, self.inputContextToken === token {
                _ = self.releaseInputContext(token)
            }
            // A later context may have requested release while this work was queued.
            // If busy, the active operation schedules its own idle recheck.
            self.schedulePendingInputContextReleaseIfIdle()
        }
    }

    var inputActivityIsBusy: Bool {
        precondition(Thread.isMainThread)
        return lifecycleOperationInFlight || drainingInputActivityIdleWork || state == .handling || queryDepth != 0
    }

    /// Runs once on a later scheduler turn after adapter mutations and queries
    /// have unwound. A nested event loop may make that later turn busy again.
    func whenInputActivityIdle(_ work: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        pendingInputActivityIdleWork.append(work)
        scheduleInputActivityIdleDrainIfPossible()
    }

    private func scheduleInputActivityIdleDrainIfPossible() {
        guard !lifecycleOperationInFlight, state != .handling, queryDepth == 0, !inputActivityIdleDrainScheduled,
              !drainingInputActivityIdleWork, !pendingInputActivityIdleWork.isEmpty else { return }
        inputActivityIdleDrainScheduled = true
        schedule { [self] in
            inputActivityIdleDrainScheduled = false
            // An operation may have entered a nested event loop after scheduling.
            // Its exit schedules the next drain; do not poll while it is active.
            guard !lifecycleOperationInFlight, state != .handling, queryDepth == 0, !drainingInputActivityIdleWork,
                  !pendingInputActivityIdleWork.isEmpty else { return }
            drainingInputActivityIdleWork = true
            let work = pendingInputActivityIdleWork.removeFirst()
            work()
            drainingInputActivityIdleWork = false
            view.flushAccessibilityNotificationsIfNeeded()
            schedulePendingInputContextReleaseIfIdle()
            scheduleInputActivityIdleDrainIfPossible()
        }
    }

    private func finishLifecycleOperation() {
        lifecycleOperationInFlight = false
        schedulePendingInputContextReleaseIfIdle()
        scheduleInputActivityIdleDrainIfPossible()
    }

    /// Accepted-change observers run inside the same event reservation.
    @discardableResult
    func setContentDidChange(_ callback: ((NSAttributedString) -> Void)?) -> Bool {
        precondition(Thread.isMainThread)
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork, state == .ready, queryDepth == 0 else { return false }
        session.contentDidChange = callback
        return true
    }

    @discardableResult
    func insertText(_ value: Any, replacementRange: NSRange) -> Outcome {
        insertTextReporting(value, replacementRange: replacementRange).outcome
    }

    func insertTextReporting(_ value: Any, replacementRange: NSRange,
                             isAvailable: () -> Bool = { true }) -> InputAttempt {
        perform { session in
            // Admission can call out. A clipboard action must not mutate after
            // losing its connection or focus during that callout.
            guard isAvailable(), let text = self.attributedInput(value),
                  !self.nestedMutationRejected, isAvailable() else { return false }
            return session.insertText(text, replacementRange: replacementRange)
        }
    }

    /// Only an explicit logical newline command may use the shared policy.
    /// Resolve against the installed snapshot after acquiring the document gate;
    /// arbitrary insertText and marked-text payloads remain literal.
    func insertLogicalNewlineReporting(isAvailable: () -> Bool = { true }) -> InputAttempt {
        insertLogicalBreakReporting(explicit: nil, isAvailable: isAvailable)
    }

    /// AppKit's line-break command explicitly requests a Unicode line separator,
    /// which is distinct from a document-style newline or paragraph break.
    func insertLogicalLineBreakReporting(isAvailable: () -> Bool = { true }) -> InputAttempt {
        insertLogicalBreakReporting(explicit: "\u{2028}", isAvailable: isAvailable)
    }

    private func insertLogicalBreakReporting(explicit: String?, isAvailable: () -> Bool) -> InputAttempt {
        perform { session in
            let selection = session.selectedRange
            guard isAvailable(), !session.hasProvisionalComposition,
                  let ending = RunestoneLineEndingPolicy.newline(in: self.view.manager.stringView.string,
                                                                 replacing: selection),
                  let attributed = self.attributedInput(explicit ?? ending), !self.nestedMutationRejected,
                  isAvailable() else { return false }
            return session.insertText(attributed, replacementRange: selection)
        }
    }

    @discardableResult
    func setMarkedText(_ value: Any, selectedRange: NSRange, replacementRange: NSRange) -> Outcome {
        setMarkedTextReporting(value, selectedRange: selectedRange, replacementRange: replacementRange).outcome
    }

    func setMarkedTextReporting(_ value: Any, selectedRange: NSRange, replacementRange: NSRange) -> InputAttempt {
        perform { session in
            guard let text = self.attributedInput(value), !self.nestedMutationRejected else { return false }
            return session.setMarkedText(text, selectedRange: selectedRange, replacementRange: replacementRange)
        }
    }

    @discardableResult
    func unmarkText() -> Outcome { unmarkTextReporting().outcome }

    func unmarkTextReporting() -> InputAttempt { perform { $0.unmarkText() } }

    /// The host must first discard its input context's conversion session.
    /// A stale composition cannot be restored and requires reconstruction.
    @discardableResult
    func cancelCompositionAfterQuiescing() -> Outcome { cancelCompositionAfterQuiescingReporting().outcome }

    func cancelCompositionAfterQuiescingReporting() -> InputAttempt { perform { $0.cancelComposition() } }

    @discardableResult
    func setSelection(_ range: NSRange) -> Outcome { setSelectionReporting(range).outcome }

    func setSelectionReporting(_ range: NSRange, isAvailable: () -> Bool = { true }) -> InputAttempt {
        perform { isAvailable() && $0.setSelection(range) }
    }

    /// Query results are available only while both the view and canonical revision
    /// match. Geometry providers may call out, so all results are checked again.
    /// Text and selection captured under one revision-checked input query.
    func accessibilityTextStateForInput() -> ReadOnlyDocumentView.AccessibilityTextState? {
        queryForInput(nil) {
            ReadOnlyDocumentView.AccessibilityTextState(text: view.snapshotForInputSession().string,
                                                        selection: session.selectedRange,
                                                        revision: view.contentRevision)
        }
    }

    func inputStateForHost() -> (selection: NSRange, marked: NSRange?, hasComposition: Bool)? {
        queryForInput(nil) {
            (selection: session.selectedRange, marked: session.markedRange,
             hasComposition: session.hasProvisionalComposition)
        }
    }

    /// Captures the selected UTF-16 range and matching text under one
    /// revision-checked query. A zero-length selection is a valid caret
    /// snapshot; nil means the input state could not be queried safely.
    func selectionSnapshotForHost() -> (range: NSRange, text: String)? {
        queryForInput(nil) {
            let range = session.selectedRange
            let text = view.snapshotForInputSession().string as NSString
            guard range.location >= 0, range.length >= 0, range.location <= text.length,
                  range.length <= text.length - range.location else { return nil }
            return (range: range, text: text.substring(with: range))
        }
    }

    func selectedRangeForInput() -> NSRange {
        queryForInput(NSRange(location: NSNotFound, length: 0)) { session.selectedRange }
    }

    func markedRangeForInput() -> NSRange {
        queryForInput(NSRange(location: NSNotFound, length: 0)) {
            session.markedRange ?? NSRange(location: NSNotFound, length: 0)
        }
    }

    /// Read only from an adapter idle-work callback, after mutation and query
    /// stacks have unwound and before retiring the old input context. This does
    /// not consult the document or restore a potentially stale baseline.
    var hasProvisionalCompositionForRetirement: Bool {
        precondition(Thread.isMainThread && drainingInputActivityIdleWork && state != .handling && queryDepth == 0)
        return session?.hasProvisionalComposition ?? false
    }

    /// A composition can remain provisional even when an empty marked update
    /// has no visible marked range. nil means the session is unavailable.
    func hasProvisionalCompositionForInput() -> Bool? {
        queryForInput(nil as Bool?) { session.hasProvisionalComposition }
    }

    func attributedSubstringForInput(range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        let content: NSAttributedString? = queryForInput(nil) {
            guard validInputRange(range) else { return nil }
            return view.attributedContent(in: range)
        }
        if content != nil { actualRange?.pointee = range }
        return content
    }

    func firstRectForInput(range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        let result: InputScreenRangeGeometry.RangeGeometry? = queryForInput(nil) {
            guard validInputRange(range), let geometry = rectProvider(range, view),
                  validInputRange(geometry.actualRange), geometry.rect.origin.x.isFinite,
                  geometry.rect.origin.y.isFinite, geometry.rect.size.width.isFinite,
                  geometry.rect.size.height.isFinite else { return nil }
            return geometry
        }
        guard let result = result else { return .zero }
        actualRange?.pointee = result.actualRange
        return result.rect
    }

    func characterIndexForInput(point: NSPoint) -> Int {
        queryForInput(NSNotFound) {
            guard point.x.isFinite, point.y.isFinite, let index = indexProvider(point, view),
                  validInputRange(NSRange(location: index, length: 0)) else { return NSNotFound }
            return index
        }
    }

    private func queryForInput<T>(_ fallback: T, _ body: () -> T) -> T {
        precondition(Thread.isMainThread)
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork,
              (state == .ready || state == .handling), let session = session,
              let revision = session.installedRevisionForInput else { return fallback }
        // Revision providers can reenter or run a nested event loop too.
        queryDepth += 1
        defer {
            queryDepth -= 1
            if queryDepth == 0 && queryNeedsReset {
                queryNeedsReset = false
                if state == .ready { scheduleReset() }
                else if state == .handling { nestedMutationRejected = true }
            }
            schedulePendingInputContextReleaseIfIdle()
            scheduleInputActivityIdleDrainIfPossible()
        }
        guard !session.isStale, !session.hasDocumentConflict, documentRevision() == revision else {
            queryNeedsReset = true
            return fallback
        }
        let viewRevision = view.contentRevision
        let result = body()
        guard !queryNeedsReset, !session.isStale, !session.hasDocumentConflict,
              session.installedRevisionForInput == revision, view.contentRevision == viewRevision,
              documentRevision() == revision else {
            queryNeedsReset = true
            return fallback
        }
        return result
    }

    private func validInputRange(_ range: NSRange) -> Bool {
        let text = view.manager.stringView.string
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return false }
        func boundary(_ index: Int) -> Bool {
            index == 0 || index == text.length ||
                !(0xD800...0xDBFF).contains(text.character(at: index - 1)) ||
                !(0xDC00...0xDFFF).contains(text.character(at: index))
        }
        return boundary(range.location) && boundary(range.location + range.length)
    }

    private func attributedInput(_ value: Any) -> NSAttributedString? {
        if let attributed = value as? NSAttributedString { return NSAttributedString(attributedString: attributed) }
        if let string = value as? String { return NSAttributedString(string: string, attributes: typingAttributes()) }
        return nil
    }

    /// Each operation synchronously enters the session after acquiring the gate.
    @discardableResult
    private func perform(_ operation: (DocumentInputSession) -> Bool) -> InputAttempt {
        precondition(Thread.isMainThread)
        defer {
            schedulePendingInputContextReleaseIfIdle()
            scheduleInputActivityIdleDrainIfPossible()
        }
        func rejected(_ outcome: Outcome, _ reason: InputFailure.Reason,
                      _ effect: InputFailure.Effect) -> InputAttempt {
            InputAttempt(outcome: outcome, failure: InputFailure(reason: reason, effect: effect))
        }
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork else {
            return rejected(.unavailable, .unavailable, .notApplied)
        }
        if queryDepth > 0 {
            queryNeedsReset = true
            if state == .handling { nestedMutationRejected = true }
            return rejected(.resetRequired, .reentrant, .notApplied)
        }
        if state == .handling {
            nestedMutationRejected = true
            return rejected(.resetRequired, .reentrant, .notApplied)
        }
        guard state == .ready, let revision = session.installedRevisionForInput else {
            return rejected(state == .resetPending ? .resetRequired : .unavailable, .unavailable, .notApplied)
        }
        state = .handling
        nestedMutationRejected = false
        let lease: Reservation
        switch beginEvent(revision) {
        case let .reserved(reservation): lease = reservation
        case .busy:
            scheduleReset()
            return rejected(.resetRequired, .busy, .notApplied)
        case .stale:
            scheduleReset()
            return rejected(.resetRequired, .stale, .notApplied)
        }
        reservation = lease
        let result: Bool
        if !nestedMutationRejected && documentRevision() == revision {
            result = operation(session) && !session.hasDocumentConflict
        } else {
            result = false
        }
        // Keep state closed to new input during release, which may call out.
        reservation = nil
        lease.close()
        let isCurrent: Bool
        if let installed = session.installedRevisionForInput, let current = documentRevision() {
            isCurrent = installed == current
        } else {
            isCurrent = false
        }
        let accepted = result && !nestedMutationRejected && isCurrent && !session.isStale && !session.hasDocumentConflict
        if accepted {
            state = .ready
            return InputAttempt(outcome: .processed, failure: nil)
        }
        scheduleReset()
        // The session may already have published. Never invite a caller to
        // retry an admitted operation, even when this particular failure
        // happened before its publication.
        return rejected(.resetRequired, .admittedFailure, .mayHaveApplied)
    }

    /// Adopts the latest gated canonical snapshot without a live input client.
    /// A real host must first prove its context and driver calls are quiescent.
    @discardableResult
    func reconstructWithoutInputContext() -> Outcome {
        precondition(Thread.isMainThread)
        defer {
            schedulePendingInputContextReleaseIfIdle()
            scheduleInputActivityIdleDrainIfPossible()
        }
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork else { return .unavailable }
        if queryDepth > 0 {
            queryNeedsReset = true
            if state == .handling { nestedMutationRejected = true }
            return .resetRequired
        }
        if state == .handling {
            nestedMutationRejected = true
            return .resetRequired
        }
        guard inputContextToken == nil, state == .ready || state == .resetPending else { return .unavailable }
        state = .handling
        nestedMutationRejected = false
        guard case let .reserved(lease) = beginReconstruction() else {
            scheduleReset()
            return .resetRequired
        }
        let revision = lease.revision
        let adopted = !nestedMutationRejected && documentRevision() == revision &&
            session.adoptCanonicalSnapshot(lease.snapshot, revision: revision)
        lease.close()
        let current = documentRevision() == revision && session.installedRevisionForInput == revision
        guard adopted, current, !nestedMutationRejected, !session.hasDocumentConflict else {
            scheduleReset()
            return .resetRequired
        }
        state = .ready
        return .processed
    }

    private func scheduleReset() {
        state = .resetPending
        let generation = UUID()
        resetGeneration = generation
        schedule { [weak self] in
            guard let self = self, self.state == .resetPending, self.resetGeneration == generation else { return }
            // The host must additionally wait for its context/driver call
            // depth to reach zero; a queued block is not itself quiescence.
            self.requestReset()
        }
    }

    /// Only usable once the host has detached its input client and stopped all
    /// queries and callbacks. Reconstruction must use a fresh permit/session.
    @discardableResult
    func disconnectAfterQuiescing() -> Bool {
        precondition(Thread.isMainThread)
        guard !lifecycleOperationInFlight, !drainingInputActivityIdleWork, queryDepth == 0, inputContextToken == nil,
              state == .ready || state == .resetPending, !session.hasProvisionalComposition,
              !session.hasDocumentConflict, let revision = session.installedRevisionForInput else { return false }
        lifecycleOperationInFlight = true
        defer { finishLifecycleOperation() }
        guard documentRevision() == revision else { return false }
        guard view.releaseInputMutation(permit) else { return false }
        state = .disconnected
        ownsPermit = false
        session = nil
        return true
    }

    /// Retires an abandoned input owner without reading the document or gate.
    /// The context must already be detached, and adapter activity must be idle.
    @discardableResult
    func retireAfterQuiescing() -> Bool {
        precondition(Thread.isMainThread)
        if state == .disconnected { return true }
        guard view.isRetired, !lifecycleOperationInFlight, !drainingInputActivityIdleWork,
              state != .handling, queryDepth == 0, inputContextToken == nil else { return false }
        guard view.releaseInputMutation(permit) else { return false }
        state = .disconnected
        ownsPermit = false
        session = nil
        return true
    }

    // Returning from this helper destroys its local payload reference before
    // the gate opens. The owner also no longer retains it in a stored slot.
    private func transferPayloadToMain(gate: NSLock, shouldRetire: Bool) {
        guard let captured = payload else { return }
        payload = nil
        if shouldRetire { captured.view.quarantineInputViewWithoutCallouts() }
        DispatchQueue.main.async {
            gate.lock()
            gate.unlock()
            if shouldRetire { captured.view.releaseInputMutationWhenIdle(captured.permit) }
            withExtendedLifetime(captured) {}
        }
    }

    deinit {
        let gate = NSLock()
        gate.lock()
        transferPayloadToMain(gate: gate, shouldRetire: ownsPermit)
        gate.unlock()
    }
}
#endif
