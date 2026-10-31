#if canImport(AppKit)
import Foundation

/// Coalesces changes into asynchronous, nonrecursive delivery to an attached host.
///
/// The owner must call all methods on the same serial executor. The scheduler
/// must enqueue work asynchronously on that executor, never invoke it inline.
/// Delivery owns no input context; a host should weakly capture itself when
/// attaching a callback and detach before disconnecting its context.
final class InputInvalidationDelivery {
    typealias Scheduler = (@escaping () -> Void) -> Void

    private let schedule: Scheduler
    private var callback: (() -> Void)?
    private var attachment = UUID()
    private var isPending = false
    private var isScheduled = false
    private var isDelivering = false
    private var suspensionDepth = 0

    init(schedule: @escaping Scheduler = { work in DispatchQueue.main.async(execute: work) }) {
        self.schedule = schedule
    }

    /// Replaces the current attachment. Work from an earlier attachment cannot
    /// deliver to this callback, even if it runs after this call.
    func attach(_ callback: @escaping () -> Void) {
        attachment = UUID()
        isPending = false
        isScheduled = false
        self.callback = callback
    }

    /// Disconnects the callback and makes already-enqueued work inert.
    func detach() {
        attachment = UUID()
        isPending = false
        isScheduled = false
        callback = nil
    }

    /// Defers delivery while a layout transaction can expose partial geometry.
    func suspend() { suspensionDepth += 1 }

    func resume() {
        precondition(suspensionDepth > 0)
        suspensionDepth -= 1
        scheduleIfNeeded()
    }

    /// Coalesces pending changes. An invalidation raised by a callback queues a
    /// separate delivery on a later executor turn.
    func invalidate() {
        guard callback != nil else { return }
        isPending = true
        scheduleIfNeeded()
    }

    private func scheduleIfNeeded() {
        guard callback != nil, isPending, !isScheduled, !isDelivering, suspensionDepth == 0 else { return }
        isScheduled = true
        let scheduledAttachment = attachment
        schedule { [weak self] in
            self?.deliver(for: scheduledAttachment)
        }
    }

    private func deliver(for scheduledAttachment: UUID) {
        guard attachment == scheduledAttachment else { return }
        isScheduled = false
        guard suspensionDepth == 0, isPending, let callback = callback else { return }
        isPending = false
        isDelivering = true
        defer {
            isDelivering = false
            scheduleIfNeeded()
        }
        callback()
    }
}
#endif
