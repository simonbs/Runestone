#if canImport(AppKit)
import AppKit

/// Bridges an opted-in host's outer dispatch lease to the adapter's sequential
/// operation leases. No AppKit event or user input is retained here.
/// All entry points run on the main thread.
final class PreparedInputDispatchCoordinator {
    private enum State { case idle, admitting, running, finishing, reporting }

    private weak var host: (any RunestoneInputDispatchHost)?
    private weak var source: ReadOnlyDocumentView?
    private let gateReleased: () -> Void
    private var state: State = .idle
    private var lease: (any RunestoneInputDispatchReservation)?
    private var child: ChildReservation?
    private var acquiringChild = false
    private var operationFailed = false
    private var pendingCompositionDiscard = false

    init(host: any RunestoneInputDispatchHost, source: ReadOnlyDocumentView,
         gateReleased: @escaping () -> Void) {
        self.host = host
        self.source = source
        self.gateReleased = gateReleased
    }

    /// True only while the admitted body can obtain child operations.
    var isActive: Bool { state == .running }

    /// Returns true exactly when body was entered. Completion is reported once,
    /// synchronously, while retaining the host and source; it is not a replay
    /// instruction. If either weak reference has expired there is no recipient.
    @discardableResult
    func perform(expectedRevision: UUID?, body: () -> Bool, isStillCurrent: () -> Bool) -> Bool {
        precondition(Thread.isMainThread)
        guard let host = host, let source = source else { return false }
        let id = UUID()
        guard state == .idle else {
            host.inputDispatchDidComplete(.init(kind: .inputDispatch, id: id, expectedRevision: expectedRevision,
                finalRevision: nil, outcome: .rejectedBeforeAdmission(.busy)), source: source)
            return false
        }
        state = .admitting
        guard let expectedRevision = expectedRevision, !source.isRetired else {
            report(host, source, id: id, expectedRevision: expectedRevision, finalRevision: nil,
                   outcome: .rejectedBeforeAdmission(.unavailable))
            return false
        }
        let parent: any RunestoneInputDispatchReservation
        switch host.beginInputDispatch(expectedRevision: expectedRevision, source: source) {
        case .busy:
            report(host, source, id: id, expectedRevision: expectedRevision, finalRevision: nil,
                   outcome: .rejectedBeforeAdmission(.busy))
            return false
        case .stale:
            report(host, source, id: id, expectedRevision: expectedRevision, finalRevision: nil,
                   outcome: .rejectedBeforeAdmission(.stale))
            return false
        case let .reserved(reservation): parent = reservation
        }
        lease = parent
        operationFailed = false
        var entered = false
        var succeeded = false
        if !source.isRetired && host.inputRevision == expectedRevision {
            state = .running
            entered = true
            succeeded = body()
        }
        state = .finishing
        // A client must close each child synchronously. If it fails to do so,
        // close it before releasing the parent and report uncertainty.
        if let child = child {
            operationFailed = true
            child.close()
        }
        let finalRevision = host.inputRevision
        lease = nil
        parent.close()
        // Closing can synchronously invalidate the connection or violate the
        // gate contract. Preserve the under-gate identity but report any such
        // interruption conservatively.
        let completed = entered && succeeded && !operationFailed && !source.isRetired &&
            host.inputRevision == finalRevision && isStillCurrent()
        report(host, source, id: id, expectedRevision: expectedRevision, finalRevision: finalRevision,
               outcome: completed ? .completed : .mayHaveApplied)
        gateReleased()
        return entered
    }

    /// Check the adapter's current installed revision while the parent is held.
    func isCurrent(revision: UUID?) -> Bool {
        guard state == .running, let revision = revision, let host = host else { return false }
        return host.inputRevision == revision
    }

    /// Must be called only by the currently admitted body. There is at most
    /// one child at a time; closing it never releases the outer reservation.
    func beginOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        precondition(Thread.isMainThread)
        guard state == .running, let lease = lease, let host = host, let source = source,
              !source.isRetired else {
            if state == .running { operationFailed = true }
            return .busy
        }
        guard child == nil, !acquiringChild else {
            operationFailed = true
            return .busy
        }
        guard host.inputRevision == expectedRevision else {
            operationFailed = true
            return .stale
        }
        acquiringChild = true
        let result = lease.beginInputOperation(expectedRevision: expectedRevision)
        acquiringChild = false
        switch result {
        case .busy:
            operationFailed = true
            return .busy
        case .stale:
            operationFailed = true
            return .stale
        case let .reserved(reservation):
            guard state == .running, !source.isRetired, host.inputRevision == expectedRevision else {
                operationFailed = true
                reservation.close()
                return .stale
            }
            let wrapper = ChildReservation(reservation: reservation) { [weak self] in self?.child = nil }
            child = wrapper
            return .reserved(wrapper)
        }
    }

    /// A discarded composition is a separate lifecycle notice, not part of
    /// an earlier event. If host or source is gone, delivery is impossible.
    func reportCompositionDiscarded() {
        precondition(Thread.isMainThread)
        guard state == .idle else {
            pendingCompositionDiscard = true
            return
        }
        guard let host = host, let source = source else { return }
        state = .reporting
        host.inputDispatchDidComplete(.init(kind: .compositionDiscarded, id: UUID(), expectedRevision: nil,
            finalRevision: nil, outcome: .mayHaveApplied), source: source)
        state = .idle
        flushCompositionDiscardIfNeeded()
    }

    private func report(_ host: any RunestoneInputDispatchHost, _ source: ReadOnlyDocumentView,
                        id: UUID, expectedRevision: UUID?, finalRevision: UUID?,
                        outcome: RunestoneInputDispatchCompletion.Outcome) {
        state = .reporting
        host.inputDispatchDidComplete(.init(kind: .inputDispatch, id: id, expectedRevision: expectedRevision,
            finalRevision: finalRevision, outcome: outcome), source: source)
        state = .idle
        flushCompositionDiscardIfNeeded()
    }

    private func flushCompositionDiscardIfNeeded() {
        guard state == .idle, pendingCompositionDiscard else { return }
        pendingCompositionDiscard = false
        reportCompositionDiscarded()
    }

    private final class ChildReservation: RunestoneInputEventReservation {
        private var reservation: (any RunestoneInputEventReservation)?
        private let didClose: () -> Void

        init(reservation: any RunestoneInputEventReservation, didClose: @escaping () -> Void) {
            self.reservation = reservation
            self.didClose = didClose
        }
        func prepare(candidate: NSAttributedString) -> (any RunestoneInputPreparedPublication)? {
            reservation?.prepare(candidate: candidate)
        }
        func close() {
            guard let reservation = reservation else { return }
            self.reservation = nil
            reservation.close()
            didClose()
        }
    }
}
#endif
