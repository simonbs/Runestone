#if canImport(AppKit)
import AppKit

/// A bounded, cancellable per-gesture tick source. It retains only the latest
/// screen point, never an NSEvent. The owner must capture itself weakly in
/// `step`, validate its document and focus, and bound each scroll/layout step.
/// All calls, callbacks and scheduler operations run on the main thread.
final class PreparedInputAutoscrollClock {
    typealias Cancellation = () -> Void
    /// Enqueue on a later turn; invoking `work` inline violates the contract.
    typealias Enqueue = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Cancellation
    typealias Step = (NSPoint) -> Bool

    private let interval: TimeInterval
    private let maximumFrames: Int
    private let maximumDuration: TimeInterval
    private let now: () -> TimeInterval
    private let enqueue: Enqueue
    private let step: Step
    private var generation = UUID()
    private var pendingID: UUID?
    private var cancelPending: Cancellation?
    private var point: NSPoint?
    private var startTime: TimeInterval?
    private var lastTime: TimeInterval?
    private var frames = 0
    private var isStepping = false
    private var isScheduling = false

    /// Production ticks run in common run-loop modes so they can fire during
    /// AppKit mouse tracking. A token and explicit timer cancellation protect
    /// against late callbacks after stop or a new gesture.
    init(interval: TimeInterval = 1.0 / 60.0, maximumFrames: Int = 120,
         maximumDuration: TimeInterval = 2.0,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         enqueue: @escaping Enqueue = { delay, work in
             let timer = Timer(timeInterval: delay, repeats: false) { _ in work() }
             RunLoop.main.add(timer, forMode: .common)
             return { timer.invalidate() }
         }, step: @escaping Step) {
        precondition(interval.isFinite && interval > 0 && maximumFrames > 0 &&
                     maximumDuration.isFinite && maximumDuration > 0)
        self.interval = interval
        self.maximumFrames = maximumFrames
        self.maximumDuration = maximumDuration
        self.now = now
        self.enqueue = enqueue
        self.step = step
    }

    var isRunning: Bool {
        precondition(Thread.isMainThread)
        return point != nil
    }

    /// Starts one gesture. A later `update` changes the pointer without
    /// restarting its frame or time budget. Returns false for invalid input.
    @discardableResult
    func begin(at screenPoint: NSPoint) -> Bool {
        precondition(Thread.isMainThread)
        stop()
        let time = now()
        guard screenPoint.x.isFinite, screenPoint.y.isFinite, time.isFinite else { return false }
        point = screenPoint
        startTime = time
        lastTime = time
        frames = 0
        scheduleIfNeeded()
        return isRunning
    }

    /// Updates only an active gesture; exhaustion cannot implicitly restart it.
    func update(_ screenPoint: NSPoint) {
        precondition(Thread.isMainThread)
        guard isRunning else { return }
        guard screenPoint.x.isFinite, screenPoint.y.isFinite else { stop(); return }
        point = screenPoint
        scheduleIfNeeded()
    }

    /// Invalidates any queued work and releases its pointer immediately.
    func stop() {
        precondition(Thread.isMainThread)
        generation = UUID()
        point = nil
        startTime = nil
        lastTime = nil
        frames = 0
        pendingID = nil
        let cancel = cancelPending
        cancelPending = nil
        cancel?()
    }

    private func scheduleIfNeeded() {
        guard isRunning, pendingID == nil, !isStepping, !isScheduling else { return }
        let expectedGeneration = generation
        let id = UUID()
        pendingID = id
        isScheduling = true
        let cancel = enqueue(interval) { [weak self] in
            guard let self = self else { return }
            precondition(!self.isScheduling, "Autoscroll scheduler must enqueue asynchronously")
            self.tick(generation: expectedGeneration, id: id)
        }
        isScheduling = false
        // A reentrant stop invalidates the newly enqueued work too.
        guard generation == expectedGeneration, pendingID == id, isRunning else {
            cancel()
            scheduleIfNeeded()
            return
        }
        cancelPending = cancel
    }

    private func tick(generation expectedGeneration: UUID, id: UUID) {
        precondition(Thread.isMainThread)
        guard generation == expectedGeneration, pendingID == id, let point = point,
              let start = startTime, let previous = lastTime else { return }
        pendingID = nil
        cancelPending = nil
        let time = now()
        guard time.isFinite, time >= previous, time >= start,
              time - start <= maximumDuration, frames < maximumFrames else { stop(); return }
        lastTime = time
        frames += 1
        isStepping = true
        let shouldContinue = step(point)
        isStepping = false
        guard generation == expectedGeneration, isRunning else { scheduleIfNeeded(); return }
        guard shouldContinue, frames < maximumFrames else { stop(); return }
        let after = now()
        guard after.isFinite, after >= time, after - start < maximumDuration else { stop(); return }
        lastTime = after
        scheduleIfNeeded()
    }

    deinit {
        let cancel = cancelPending
        if Thread.isMainThread { cancel?() }
        else { DispatchQueue.main.async { cancel?() } }
    }
}
#endif
