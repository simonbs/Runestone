import Foundation

/// The wrapper owns canceled resources exclusively. Clearing its fields releases
/// them on the selected executor even if the wrapper itself still has a caller.
final class TreeSitterHighlightResources {
    private var snapshot: TreeSitterHighlightSnapshot?
    private var completed: TreeSitterHighlightRequest.Completed?

    init(snapshot: TreeSitterHighlightSnapshot?, completed: TreeSitterHighlightRequest.Completed?) {
        self.snapshot = snapshot
        self.completed = completed
    }

    func clear() {
        snapshot = nil
        completed = nil
    }
}

/// At most one canceled payload may await or undergo background destruction.
/// Bursts apply synchronous backpressure instead of retaining a queue of old
/// documents. This queue never owns an executing query's snapshot.
final class TreeSitterHighlightResourceDisposer {
    static let shared = TreeSitterHighlightResourceDisposer(queue: {
        let queue = OperationQueue()
        queue.name = "Runestone.HighlightResourceDisposal"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }())

    private let queue: OperationQueue
    private let lock = NSLock()
    private var isDisposing = false

    // The executor must remain active. Production owns a dedicated private queue;
    // injection lets lifetime tests suspend and drain their own isolated queue.
    init(queue: OperationQueue) {
        self.queue = queue
    }

    func dispose(_ resources: TreeSitterHighlightResources) {
        lock.lock()
        let canDisposeAsynchronously = !isDisposing
        if canDisposeAsynchronously { isDisposing = true }
        lock.unlock()

        guard canDisposeAsynchronously else {
            resources.clear()
            return
        }
        queue.addOperation { [self, resources] in
            autoreleasepool {
                resources.clear()
            }
            // Release the slot only after the heavy fields have been cleared;
            // the operation closure can outlive this point without retaining them.
            lock.lock()
            isDisposing = false
            lock.unlock()
        }
    }
}
