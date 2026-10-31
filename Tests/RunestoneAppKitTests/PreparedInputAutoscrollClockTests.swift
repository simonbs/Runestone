#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputAutoscrollClockTests: XCTestCase {
    func testUpdatesCoalesceAndUseOnlyLatestPointer() {
        let scheduler = AutoscrollManualScheduler()
        var time: TimeInterval = 0
        var points: [NSPoint] = []
        let clock = PreparedInputAutoscrollClock(interval: 0.1, maximumFrames: 3, maximumDuration: 2,
            now: { time }, enqueue: scheduler.enqueue) { point in points.append(point); return true }
        XCTAssertTrue(clock.begin(at: NSPoint(x: 1, y: 2)))
        clock.update(NSPoint(x: 3, y: 4))
        clock.update(NSPoint(x: 5, y: 6))
        XCTAssertEqual(scheduler.pendingCount, 1)
        time = 0.1
        scheduler.runNext()
        XCTAssertEqual(points, [NSPoint(x: 5, y: 6)])
        XCTAssertEqual(scheduler.pendingCount, 1)
        clock.stop()
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testFrameBudgetStopsWithoutImplicitRestart() {
        let scheduler = AutoscrollManualScheduler()
        var time: TimeInterval = 0
        var calls = 0
        let clock = PreparedInputAutoscrollClock(interval: 0.1, maximumFrames: 3, maximumDuration: 10,
            now: { time }, enqueue: scheduler.enqueue) { _ in calls += 1; return true }
        XCTAssertTrue(clock.begin(at: .zero))
        for step in 1...3 { time = Double(step) / 10; scheduler.runNext() }
        XCTAssertEqual(calls, 3)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)
        clock.update(NSPoint(x: 10, y: 10))
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testDurationAndNoProgressStopWithoutPolling() {
        let scheduler = AutoscrollManualScheduler()
        var time: TimeInterval = 0
        var calls = 0
        let clock = PreparedInputAutoscrollClock(interval: 0.1, maximumFrames: 10, maximumDuration: 0.25,
            now: { time }, enqueue: scheduler.enqueue) { _ in calls += 1; return true }
        XCTAssertTrue(clock.begin(at: .zero))
        time = 0.1
        scheduler.runNext()
        time = 0.3
        scheduler.runNext()
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)

        let noProgress = PreparedInputAutoscrollClock(interval: 0.1, now: { time }, enqueue: scheduler.enqueue) { _ in false }
        XCTAssertTrue(noProgress.begin(at: .zero))
        time = 0.4
        scheduler.runNext()
        XCTAssertFalse(noProgress.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testStopAndNewGestureIgnoreLateCancelledCallback() {
        let scheduler = AutoscrollManualScheduler()
        var time: TimeInterval = 0
        var points: [NSPoint] = []
        let clock = PreparedInputAutoscrollClock(interval: 0.1, now: { time }, enqueue: scheduler.enqueue) {
            points.append($0); return true
        }
        XCTAssertTrue(clock.begin(at: NSPoint(x: 1, y: 1)))
        let stale = scheduler.latestAction
        clock.stop()
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertTrue(clock.begin(at: NSPoint(x: 2, y: 2)))
        XCTAssertEqual(scheduler.pendingCount, 1)
        time = 0.1
        stale?() // Simulates a callback already enqueued when cancellation won.
        XCTAssertTrue(points.isEmpty)
        XCTAssertEqual(scheduler.pendingCount, 1)
        scheduler.runNext()
        XCTAssertEqual(points, [NSPoint(x: 2, y: 2)])
        clock.stop()
    }

    func testInvalidPointerOrNonmonotonicClockStops() {
        let scheduler = AutoscrollManualScheduler()
        var time: TimeInterval = 1
        var calls = 0
        let clock = PreparedInputAutoscrollClock(interval: 0.1, now: { time }, enqueue: scheduler.enqueue) { _ in
            calls += 1; return true
        }
        XCTAssertFalse(clock.begin(at: NSPoint(x: CGFloat.nan, y: 0)))
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertTrue(clock.begin(at: .zero))
        clock.update(NSPoint(x: CGFloat.infinity, y: 0))
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertTrue(clock.begin(at: .zero))
        time = 0.9
        scheduler.runNext()
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testReentrantStopAndBeginStartsOnlyTheNewGesture() {
        let scheduler = AutoscrollManualScheduler()
        var time: TimeInterval = 0
        var points: [NSPoint] = []
        var clock: PreparedInputAutoscrollClock!
        clock = PreparedInputAutoscrollClock(interval: 0.1, maximumFrames: 2, maximumDuration: 2,
            now: { time }, enqueue: scheduler.enqueue) { point in
                points.append(point)
                if points.count == 1 {
                    clock.stop()
                    XCTAssertTrue(clock.begin(at: NSPoint(x: 3, y: 4)))
                }
                return true
            }
        XCTAssertTrue(clock.begin(at: NSPoint(x: 1, y: 2)))
        time = 0.1
        scheduler.runNext()
        XCTAssertEqual(scheduler.pendingCount, 1)
        time = 0.2
        scheduler.runNext()
        XCTAssertEqual(points, [NSPoint(x: 1, y: 2), NSPoint(x: 3, y: 4)])
        clock.stop()
        clock = nil
    }

    func testReleasingClockCancelsPendingWork() {
        let scheduler = AutoscrollManualScheduler()
        var calls = 0
        var clock: PreparedInputAutoscrollClock? = PreparedInputAutoscrollClock(now: { 0 }, enqueue: scheduler.enqueue) { _ in
            calls += 1; return true
        }
        XCTAssertTrue(clock!.begin(at: .zero))
        let stale = scheduler.latestAction
        clock = nil
        XCTAssertEqual(scheduler.pendingCount, 0)
        stale?()
        XCTAssertEqual(calls, 0)
    }
}

private final class AutoscrollManualScheduler {
    private struct Entry {
        let id: UUID
        let action: () -> Void
        var cancelled: Bool
    }
    private var entries: [Entry] = []
    var pendingCount: Int { entries.filter { !$0.cancelled }.count }
    var latestAction: (() -> Void)? { entries.last?.action }
    func enqueue(_ delay: TimeInterval, _ action: @escaping () -> Void) -> () -> Void {
        XCTAssertGreaterThan(delay, 0)
        let id = UUID()
        entries.append(Entry(id: id, action: action, cancelled: false))
        return { [weak self] in
            guard let self = self, let index = self.entries.firstIndex(where: { $0.id == id }) else { return }
            self.entries[index].cancelled = true
        }
    }
    func runNext() {
        guard let index = entries.firstIndex(where: { !$0.cancelled }) else { XCTFail("No pending tick"); return }
        let entry = entries.remove(at: index)
        entry.action()
    }
}
#endif
