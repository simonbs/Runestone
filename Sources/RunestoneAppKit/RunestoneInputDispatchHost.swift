#if canImport(AppKit)
import AppKit

/// The result of reserving the document gate for one synchronous input
/// dispatch. Busy and stale reject the dispatch before AppKit sees it.
public enum RunestoneInputDispatchStart {
    case reserved(RunestoneInputDispatchReservation)
    case busy
    case stale
}

/// The outer reservation for one input dispatch. This is distinct from the
/// single-operation `RunestoneInputEventReservation`.
///
/// All methods run on the main thread. From admission until `close()` returns,
/// the host must exclude competing input dispatches, reconstructions, saves,
/// reads, undo, redo, and every other document mutation or state establishment.
/// The host must permit this reservation's sequential child operations through
/// that same gate. A child is closed before the next child begins. Each child
/// uses the current installed revision, which may have advanced after an
/// earlier publication in this dispatch. The host must reject a stale revision
/// and preserve the existing child reservation's publication and undo contract.
///
/// The framework closes all children before synchronously closing the outer
/// reservation exactly once. `close()` must release the gate, and must not
/// retain or replay input events. The reservation does not extend across later
/// asynchronous input-method callbacks; those require separate admission.
public protocol RunestoneInputDispatchReservation: AnyObject {
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart
    func close()
}

/// A document-owned history operation requested by an input command.
public enum RunestoneInputHistoryOperation: Equatable {
    case undo
    case redo
}

/// The outcome of a document-owned history request. No case authorizes replay.
public enum RunestoneInputHistoryResult: Equatable {
    /// The operation completed and this revision was captured under its gate.
    case success(finalRevision: UUID)
    /// The gate was occupied; the operation was not entered.
    case busy
    /// The expected revision did not match; the operation was not entered.
    case stale
    /// The host cannot perform this operation; it was not entered.
    case unavailable
    /// The operation was entered but its effects could not be confirmed.
    /// If available, the revision was captured while the document gate was held.
    case mayHaveApplied(finalRevision: UUID?)
}

/// A metadata-only result for an input dispatch or a lifecycle notice.
///
/// `id` is unique to the attempt. `expectedRevision` identifies the installed
/// snapshot used for admission, when available. For an admitted dispatch,
/// `finalRevision` is captured while its outer reservation is still held; for
/// a history command it is captured under the history operation's gate. It
/// may cease to be current once the gate is released. It is nil when a reliable
/// value cannot be captured, including an attempt rejected before admission.
/// A result never contains input text, a selection or an AppKit event.
public struct RunestoneInputDispatchCompletion: Equatable {
    public enum Kind: Equatable {
        /// The result of one synchronous dispatch attempt.
        case inputDispatch
        /// A document-owned undo or redo requested by an input command.
        /// The associated expected and final revisions identify the history
        /// attempt, not a later reconstructed view snapshot.
        case historyCommand
        /// A separate lifecycle notice that provisional composition was
        /// discarded after a dispatch. No dispatch gate is held; the outcome is
        /// `mayHaveApplied`, and revision identities may be unavailable.
        case compositionDiscarded
    }

    public enum RejectionReason: Equatable {
        case busy, stale, unavailable
    }

    public enum Outcome: Equatable {
        /// The synchronous dispatch completed without a detected failure. This
        /// does not describe callbacks that AppKit may issue later.
        case completed
        /// A dispatch was rejected before the driver, fallback or callback's
        /// operation was entered, or a history command was rejected before the
        /// document history operation was entered. This never authorizes replay.
        case rejectedBeforeAdmission(RejectionReason)
        /// An admitted dispatch failed or was interrupted; some effects may
        /// already have been published and cannot safely be replayed.
        case mayHaveApplied
    }

    public let kind: Kind
    public let id: UUID
    public let expectedRevision: UUID?
    public let finalRevision: UUID?
    public let outcome: Outcome

    public init(kind: Kind, id: UUID, expectedRevision: UUID?, finalRevision: UUID?, outcome: Outcome) {
        self.kind = kind
        self.id = id
        self.expectedRevision = expectedRevision
        self.finalRevision = finalRevision
        self.outcome = outcome
    }
}

/// Opt-in document-host capability for coordinating a whole synchronous input
/// dispatch and its ordered child operations. An implementation must own the
/// same document gate used by the base host's event and reconstruction methods.
/// All methods are called on the main thread; the host and coordination objects
/// must outlive their prepared input connections.
///
/// The framework reports exactly one completion for each attempted dispatch,
/// including a rejection, to the same host and source view. It calls the
/// completion method synchronously after that attempt's outer reservation has
/// closed. A nested attempt is rejected immediately and its completion can be
/// delivered while an earlier dispatch still holds the gate; completions are
/// delivered in completion order. The host must acknowledge the value in that call without calling out, entering a
/// nested event loop, or starting another document operation. It may copy the
/// metadata for later processing using its own bounded storage. A discarded
/// provisional composition produces a separate `compositionDiscarded` notice
/// after quiescence, with no dispatch reservation held. No raw internal
/// failure reports or input payloads are exposed. No result authorizes replay.
/// This capability does not attach an input client or expose an editable view.
public protocol RunestoneInputDispatchHost: RunestoneInputDocumentHost {
    /// Reserve before the input driver or key-binding fallback sees the event.
    /// Return stale if the expected revision no longer matches, or busy if a
    /// document operation owns the gate, without changing document state.
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart

    /// Perform a document-owned undo or redo after the enclosing input dispatch
    /// has closed its outer reservation. Atomically acquire the same document
    /// gate used by input, reconstruction and competing document operations,
    /// check `expectedRevision`, and return busy or stale without applying the
    /// operation when admission fails. Return unavailable if history cannot be
    /// performed. Once admitted, perform the operation at most once and report
    /// `mayHaveApplied` if its outcome is uncertain; never replay it.
    ///
    /// Capture the final revision under the gate. The document owns all undo,
    /// redo, publication, encoding and reconciliation behavior. Release the gate
    /// before returning, and report canonical changes and gate availability to
    /// the document bridge according to its existing notification contract.
    /// The default implementation is unavailable, preserving existing hosts.
    func performInputHistory(_ operation: RunestoneInputHistoryOperation, expectedRevision: UUID,
                             source: ReadOnlyDocumentView) -> RunestoneInputHistoryResult

    /// Acknowledge one result synchronously, without calling out or reentering.
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView)
}

public extension RunestoneInputDispatchHost {
    func performInputHistory(_ operation: RunestoneInputHistoryOperation, expectedRevision: UUID,
                             source: ReadOnlyDocumentView) -> RunestoneInputHistoryResult {
        .unavailable
    }
}
#endif
