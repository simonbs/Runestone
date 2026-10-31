#if canImport(AppKit)
import AppKit

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

    enum ReservationResult {
        case reserved(Reservation)
        case stale
        case busy
    }
    typealias BeginEvent = (UUID) -> ReservationResult
    private enum State { case ready, handling, resetPending, disconnected }

    private let view: ReadOnlyDocumentView
    private let permit: ReadOnlyDocumentView.InputMutationPermit
    private let beginEvent: BeginEvent
    private let beginReconstruction: () -> ReconstructionStart
    private let documentRevision: () -> UUID
    private let typingAttributes: () -> [NSAttributedString.Key: Any]
    private let requestReset: () -> Void
    private let rectProvider: (NSRange, ReadOnlyDocumentView) -> InputScreenRangeGeometry.RangeGeometry?
    private let indexProvider: (NSPoint, ReadOnlyDocumentView) -> Int?
    // Scheduler must enqueue asynchronously, without an inline call or nested event loop.
    private let schedule: (@escaping () -> Void) -> Void
    private var state: State = .ready
    private var reservation: Reservation?
    private var nestedMutationRejected = false
    private var queryDepth = 0
    private var queryNeedsReset = false
    private var inputContextToken: InputContextToken?
    private var pendingInputContextRelease: InputContextToken?
    private var inputContextReleaseScheduled = false
    private var pendingInputActivityIdleWork: [() -> Void] = []
    private var inputActivityIdleDrainScheduled = false
    private var drainingInputActivityIdleWork = false
    private var resetGeneration = UUID()
    private var session: DocumentInputSession!
    private var ownsPermit = true

    /// The caller has already captured the view content and revision together
    /// under the document gate, with no live input context using this view.
    init?(view: ReadOnlyDocumentView, snapshot: NSAttributedString, initialRevision: UUID,
          documentRevision: @escaping () -> UUID,
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
        guard !drainingInputActivityIdleWork, state == .ready, queryDepth == 0, inputContextToken == nil,
              !session.isStale, !session.hasDocumentConflict,
              session.installedRevisionForInput == documentRevision() else { return nil }
        let token = InputContextToken()
        inputContextToken = token
        return token
    }

    @discardableResult
    func releaseInputContext(_ token: InputContextToken) -> Bool {
        precondition(Thread.isMainThread)
        guard state != .handling, queryDepth == 0, inputContextToken === token else { return false }
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
        guard !drainingInputActivityIdleWork, state != .handling, queryDepth == 0, !inputContextReleaseScheduled,
              let token = pendingInputContextRelease else { return }
        inputContextReleaseScheduled = true
        schedule { [weak self] in
            guard let self = self else { return }
            self.inputContextReleaseScheduled = false
            if !self.drainingInputActivityIdleWork, self.state != .handling, self.queryDepth == 0,
               self.pendingInputContextRelease === token, self.inputContextToken === token {
                _ = self.releaseInputContext(token)
            }
            // A later context may have requested release while this work was queued.
            // If busy, the active operation schedules its own idle recheck.
            self.schedulePendingInputContextReleaseIfIdle()
        }
    }

    /// Runs once on a later scheduler turn after adapter mutations and queries
    /// have unwound. A nested event loop may make that later turn busy again.
    func whenInputActivityIdle(_ work: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        pendingInputActivityIdleWork.append(work)
        scheduleInputActivityIdleDrainIfPossible()
    }

    private func scheduleInputActivityIdleDrainIfPossible() {
        guard state != .handling, queryDepth == 0, !inputActivityIdleDrainScheduled,
              !drainingInputActivityIdleWork, !pendingInputActivityIdleWork.isEmpty else { return }
        inputActivityIdleDrainScheduled = true
        schedule { [self] in
            inputActivityIdleDrainScheduled = false
            // An operation may have entered a nested event loop after scheduling.
            // Its exit schedules the next drain; do not poll while it is active.
            guard state != .handling, queryDepth == 0, !drainingInputActivityIdleWork,
                  !pendingInputActivityIdleWork.isEmpty else { return }
            drainingInputActivityIdleWork = true
            let work = pendingInputActivityIdleWork.removeFirst()
            work()
            drainingInputActivityIdleWork = false
            schedulePendingInputContextReleaseIfIdle()
            scheduleInputActivityIdleDrainIfPossible()
        }
    }

    /// Accepted-change observers run inside the same event reservation.
    @discardableResult
    func setContentDidChange(_ callback: ((NSAttributedString) -> Void)?) -> Bool {
        precondition(Thread.isMainThread)
        guard !drainingInputActivityIdleWork, state == .ready, queryDepth == 0 else { return false }
        session.contentDidChange = callback
        return true
    }

    @discardableResult
    func insertText(_ value: Any, replacementRange: NSRange) -> Outcome {
        perform { session in
            guard let text = self.attributedInput(value), !self.nestedMutationRejected else { return false }
            return session.insertText(text, replacementRange: replacementRange)
        }
    }

    @discardableResult
    func setMarkedText(_ value: Any, selectedRange: NSRange, replacementRange: NSRange) -> Outcome {
        perform { session in
            guard let text = self.attributedInput(value), !self.nestedMutationRejected else { return false }
            return session.setMarkedText(text, selectedRange: selectedRange, replacementRange: replacementRange)
        }
    }

    @discardableResult
    func unmarkText() -> Outcome { perform { $0.unmarkText() } }

    /// The host must first discard its input context's conversion session.
    /// A stale composition cannot be restored and requires reconstruction.
    @discardableResult
    func cancelCompositionAfterQuiescing() -> Outcome { perform { $0.cancelComposition() } }

    @discardableResult
    func setSelection(_ range: NSRange) -> Outcome { perform { $0.setSelection(range) } }

    /// Query results are available only while both the view and canonical revision
    /// match. Geometry providers may call out, so all results are checked again.
    func selectedRangeForInput() -> NSRange {
        queryForInput(NSRange(location: NSNotFound, length: 0)) { session.selectedRange }
    }

    func markedRangeForInput() -> NSRange {
        queryForInput(NSRange(location: NSNotFound, length: 0)) {
            session.markedRange ?? NSRange(location: NSNotFound, length: 0)
        }
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
        guard !drainingInputActivityIdleWork, (state == .ready || state == .handling), let session = session,
              let revision = session.installedRevisionForInput else { return fallback }
        guard !session.isStale, !session.hasDocumentConflict, documentRevision() == revision else {
            if queryDepth > 0 { queryNeedsReset = true }
            else if state == .ready { scheduleReset() }
            else { nestedMutationRejected = true }
            return fallback
        }
        let viewRevision = view.contentRevision
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
    private func perform(_ operation: (DocumentInputSession) -> Bool) -> Outcome {
        precondition(Thread.isMainThread)
        defer {
            schedulePendingInputContextReleaseIfIdle()
            scheduleInputActivityIdleDrainIfPossible()
        }
        guard !drainingInputActivityIdleWork else { return .unavailable }
        if queryDepth > 0 {
            queryNeedsReset = true
            if state == .handling { nestedMutationRejected = true }
            return .resetRequired
        }
        if state == .handling {
            nestedMutationRejected = true
            return .resetRequired
        }
        guard state == .ready, let revision = session.installedRevisionForInput else {
            return state == .resetPending ? .resetRequired : .unavailable
        }
        state = .handling
        nestedMutationRejected = false
        guard case let .reserved(lease) = beginEvent(revision) else {
            scheduleReset()
            return .resetRequired
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
        let isCurrent = session.installedRevisionForInput == documentRevision()
        let accepted = result && !nestedMutationRejected && isCurrent && !session.hasDocumentConflict
        if accepted { state = .ready; return .processed }
        scheduleReset()
        return .resetRequired
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
        guard !drainingInputActivityIdleWork else { return .unavailable }
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
        guard !drainingInputActivityIdleWork, queryDepth == 0, inputContextToken == nil,
              state == .ready || state == .resetPending, !session.hasProvisionalComposition,
              !session.hasDocumentConflict, session.installedRevisionForInput == documentRevision() else { return false }
        guard view.releaseInputMutation(permit) else { return false }
        state = .disconnected
        ownsPermit = false
        session = nil
        return true
    }

    deinit {
        // This adapter has no input context. A real host must quiesce its client
        // before releasing the adapter, and cannot rely on this fallback alone.
        // If provisional text remains, the view must be discarded or rebuilt
        // from the latest canonical snapshot before it can be displayed or reused.
        if ownsPermit {
            let view = view
            let permit = permit
            DispatchQueue.main.async { view.releaseInputMutationWhenIdle(permit) }
        }
    }
}
#endif
