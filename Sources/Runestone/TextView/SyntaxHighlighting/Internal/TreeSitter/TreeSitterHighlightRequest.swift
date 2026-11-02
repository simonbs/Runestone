import Foundation

/// Owns document-sized resources while work is pending or awaiting main-thread
/// application. Queued closures hold this request weakly so cancellation can
/// release a completed snapshot without waiting for the main queue to drain.
final class TreeSitterHighlightRequest {
    struct Completed {
        let snapshot: TreeSitterHighlightSnapshot
        let captures: [TreeSitterCapture]
    }

    private let lock = NSLock()
    private let resourceDisposer: TreeSitterHighlightResourceDisposer
    private var pendingSnapshot: TreeSitterHighlightSnapshot?
    private var completed: Completed?
    private var isCancelled = false

    init(snapshot: TreeSitterHighlightSnapshot, resourceDisposer: TreeSitterHighlightResourceDisposer = .shared) {
        pendingSnapshot = snapshot
        self.resourceDisposer = resourceDisposer
    }

    func takeSnapshot() -> TreeSitterHighlightSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        let snapshot = pendingSnapshot
        pendingSnapshot = nil
        return snapshot
    }

    func complete(snapshot: TreeSitterHighlightSnapshot, captures: [TreeSitterCapture]) {
        lock.lock()
        defer { lock.unlock() }
        guard !isCancelled else {
            return
        }
        completed = Completed(snapshot: snapshot, captures: captures)
    }

    func takeCompleted() -> Completed? {
        lock.lock()
        defer { lock.unlock() }
        let result = completed
        completed = nil
        return result
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        guard pendingSnapshot != nil || completed != nil else {
            lock.unlock()
            return
        }
        let resources = TreeSitterHighlightResources(snapshot: pendingSnapshot, completed: completed)
        pendingSnapshot = nil
        completed = nil
        lock.unlock()
        resourceDisposer.dispose(resources)
    }
}
