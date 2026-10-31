#if canImport(AppKit)
import AppKit

/// The phase reached by a published input change when a document contract
/// violation or retirement requires reconciliation.
public enum RunestoneInputReconciliationPhase {
    case beforeFinish
    case afterFinish
    case afterNotification
}

/// A validated, already prepared document change. The framework calls these
/// methods synchronously on the main thread, while its event reservation is
/// still held. A publication must retain all data it needs independently of
/// the lifetime of the host's temporary preparation values.
public protocol RunestoneInputPreparedPublication: AnyObject {
    /// Install the prepared canonical bytes, content, metadata, and revision.
    /// This operation must not fail, notify observers, call out, or enter an
    /// event loop. A text change must advance the document revision. An
    /// attribute-only or unchanged-text candidate preserves the exact bytes,
    /// encoding, BOM, and revision.
    func publish()

    /// Register at most one document-owned undo action and notify observers.
    /// Attribute-only or unchanged-text candidates register no document undo;
    /// provisional marked edits are never published or registered as undo.
    /// Preserve the exact prior bytes, encoding, and BOM for undo. Do not
    /// release the reservation until the framework subsequently calls close.
    func finish()

    /// Reconcile a publication without overwriting a newer document revision
    /// or removing unrelated undo. Before finish, finish the accepted change
    /// only if it is still current. After finish or notification, do not
    /// register its undo a second time. The host must provide phase-aware
    /// recovery even if another operation violated the reservation contract.
    func reconcile(_ phase: RunestoneInputReconciliationPhase)
}

/// An event-scoped exclusive document reservation. The host must gate every
/// input event, save, read/revert, undo, redo, and competing document mutation
/// until close returns. Do not hold a reservation across input events.
public protocol RunestoneInputEventReservation: AnyObject {
    /// Validate the whole candidate without observable mutation or callouts.
    /// Reject invalid or lossy encoding/BOM round trips by returning nil.
    /// A successful result owns any exact prior and proposed bytes it needs.
    func prepare(candidate: NSAttributedString) -> (RunestoneInputPreparedPublication)?

    /// Synchronously finish or cancel the reservation exactly once, including
    /// a prepared publication discarded before publish. Retain the reservation
    /// through all publication, layout, notification, and reconciliation calls.
    /// The framework reports this gate release to its own view synchronizer.
    func close()
}

public enum RunestoneInputEventStart {
    case reserved(RunestoneInputEventReservation)
    case stale
    case busy
}

/// A snapshot and its matching document revision, captured together while the
/// document gate is held. Both getters must be side-effect-free and must not
/// call out. The framework copies the attributed string; its attribute values
/// must remain immutable. The reservation remains held through view layout.
public protocol RunestoneInputReconstructionReservation: AnyObject {
    var snapshot: NSAttributedString { get }
    var revision: UUID { get }
    /// Release the document gate synchronously and exactly once. The framework
    /// reports this gate release to its own view synchronizer.
    func close()
}

public enum RunestoneInputReconstructionStart {
    case reserved(RunestoneInputReconstructionReservation)
    case busy
}

/// The document-owned side of future prepared input integration.
///
/// All methods and reservation/publication callbacks run on the main thread.
/// The document owns canonical state, its revision, bytes, and undo. It must
/// advance the revision before callouts for every canonical content, encoding,
/// BOM, or metadata change. Use one gate for event and reconstruction leases
/// and for every other operation that changes or establishes document state.
/// The host must outlive its prepared view connections; avoid ownership cycles
/// between the host, reservations, publications, and their view connections.
///
/// This protocol supplies a gate only. It does not create an editable view,
/// expose an input client, or establish a first responder.
public protocol RunestoneInputDocumentHost: AnyObject {
    /// A side-effect-free read that must not call out or enter an event loop.
    var inputRevision: UUID { get }

    /// Reserve before any input mutation. Return stale when the revision no
    /// longer matches and busy when any operation owns the document gate.
    /// `source` is the originating view identity, not an editable responder.
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart

    /// Reserve the same gate and capture the current snapshot and revision
    /// atomically. Never capture one on one side of a gate release and the
    /// other on the other side. Return busy without changing state if occupied.
    func beginInputReconstruction() -> RunestoneInputReconstructionStart

    /// Attributes for committed text inserted during an input composition.
    /// They must exclude transient input-method decoration.
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any]
}
#endif
