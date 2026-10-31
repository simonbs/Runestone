#if canImport(AppKit)
import Foundation

/// Document-scoped notifications for future prepared input view integration.
/// The document owns this object; it does not own the document or its views.
/// All calls must occur on the main thread. This boundary does not attach an
/// input client, make a view editable, or create a first responder.
public final class RunestoneInputDocumentBridge {
    let synchronizer: PreparedInputViewSynchronizer
    private weak var lifetime: RunestoneInputDocumentLifetime?
    private weak var host: RunestoneInputDocumentHost?
    private var hasBoundLifetime = false

    // A bridge coordinates one document. If its owner releases it while an
    // attachment survives, the document lifetime must also be invalidated.
    func bind(host candidateHost: RunestoneInputDocumentHost, lifetime candidate: RunestoneInputDocumentLifetime) -> Bool {
        precondition(Thread.isMainThread)
        if hasBoundLifetime { return lifetime === candidate && host === candidateHost }
        host = candidateHost
        lifetime = candidate
        hasBoundLifetime = true
        return true
    }

    deinit { lifetime?.invalidate() }

    public init() {
        precondition(Thread.isMainThread)
        synchronizer = PreparedInputViewSynchronizer()
    }

    /// Notify after an external canonical content, encoding, or metadata
    /// change, outside any no-callout publication phase. All registered input
    /// views become inert until they can adopt a current gated snapshot. Accepted
    /// edits originating from a framework view are coordinated internally.
    public func canonicalDocumentDidChange() {
        precondition(Thread.isMainThread)
        synchronizer.canonicalDidChange()
    }

    /// Notify after a document operation outside this framework releases the
    /// shared gate, including read, undo, and redo. Framework-owned input and
    /// reconstruction reservations report their own releases internally; do
    /// not signal them here. Notifications are coalesced and do not assert
    /// that any input callback or AppKit operation is quiescent.
    public func documentGateDidBecomeAvailable() {
        precondition(Thread.isMainThread)
        synchronizer.documentGateDidBecomeAvailable()
    }
}
#endif
