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
    private let documentRevision: () -> UUID
    private let typingAttributes: () -> [NSAttributedString.Key: Any]
    private let requestReset: () -> Void
    // Scheduler must enqueue asynchronously, without an inline call or nested event loop.
    private let schedule: (@escaping () -> Void) -> Void
    private var state: State = .ready
    private var reservation: Reservation?
    private var nestedMutationRejected = false
    private var session: DocumentInputSession!
    private var ownsPermit = true

    /// The caller has already captured the view content and revision together
    /// under the document gate, with no live input context using this view.
    init?(view: ReadOnlyDocumentView, snapshot: NSAttributedString, initialRevision: UUID,
          documentRevision: @escaping () -> UUID,
          typingAttributes: @escaping () -> [NSAttributedString.Key: Any],
          beginEvent: @escaping BeginEvent, requestReset: @escaping () -> Void,
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
        self.documentRevision = documentRevision
        self.typingAttributes = typingAttributes
        self.requestReset = requestReset
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

    /// Accepted-change observers run inside the same event reservation.
    @discardableResult
    func setContentDidChange(_ callback: ((NSAttributedString) -> Void)?) -> Bool {
        precondition(Thread.isMainThread)
        guard state == .ready else { return false }
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

    private func attributedInput(_ value: Any) -> NSAttributedString? {
        if let attributed = value as? NSAttributedString { return NSAttributedString(attributedString: attributed) }
        if let string = value as? String { return NSAttributedString(string: string, attributes: typingAttributes()) }
        return nil
    }

    /// Each operation synchronously enters the session after acquiring the gate.
    @discardableResult
    private func perform(_ operation: (DocumentInputSession) -> Bool) -> Outcome {
        precondition(Thread.isMainThread)
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

    private func scheduleReset() {
        state = .resetPending
        schedule { [weak self] in
            guard let self = self, self.state == .resetPending else { return }
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
        guard state == .ready || state == .resetPending, !session.hasProvisionalComposition else { return false }
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
