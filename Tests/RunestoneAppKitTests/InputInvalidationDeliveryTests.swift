#if canImport(AppKit)
@testable import RunestoneAppKit
import XCTest

final class InputInvalidationDeliveryTests: XCTestCase {
    func testChangesCoalesceAsynchronouslyAndLaterChangesDeliverAgain() {
        let scheduler = ManualScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        var calls = 0
        delivery.attach { calls += 1 }

        delivery.invalidate()
        delivery.invalidate()
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(scheduler.count, 1)
        scheduler.runNext()
        XCTAssertEqual(calls, 1)

        delivery.invalidate()
        XCTAssertEqual(calls, 1)
        scheduler.runNext()
        XCTAssertEqual(calls, 2)
    }

    func testDetachAndReattachDoNotDeliverOldWorkToNewHost() {
        let scheduler = ManualScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        var oldCalls = 0
        var newCalls = 0
        delivery.attach { oldCalls += 1 }
        delivery.invalidate()
        delivery.detach()
        delivery.invalidate()
        delivery.attach { newCalls += 1 }
        delivery.invalidate()

        XCTAssertEqual(scheduler.count, 2)
        scheduler.runNext()
        XCTAssertEqual(oldCalls, 0)
        XCTAssertEqual(newCalls, 0)
        scheduler.runNext()
        XCTAssertEqual(newCalls, 1)
        XCTAssertEqual(oldCalls, 0)
    }

    func testInvalidationDuringCallbackQueuesANonrecursiveDelivery() {
        let scheduler = ManualScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        var depth = 0
        var maximumDepth = 0
        var calls = 0
        delivery.attach { [weak delivery] in
            depth += 1
            maximumDepth = max(maximumDepth, depth)
            calls += 1
            if calls == 1 {
                delivery?.invalidate()
                delivery?.invalidate()
                // A nested run loop cannot execute a follow-up before this returns.
                XCTAssertEqual(scheduler.count, 0)
            }
            depth -= 1
        }

        delivery.invalidate()
        scheduler.runNext()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(scheduler.count, 1)
        scheduler.runNext()
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(maximumDepth, 1)
    }

    func testDetachingInsideCallbackCancelsFollowUp() {
        let scheduler = ManualScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        var calls = 0
        delivery.attach { [weak delivery] in
            calls += 1
            delivery?.invalidate()
            delivery?.detach()
        }

        delivery.invalidate()
        scheduler.runNext()
        XCTAssertEqual(scheduler.count, 0)
        XCTAssertEqual(calls, 1)
    }

    func testQueuedDeliveryWaitsForSuspendedLayout() {
        let scheduler = ManualScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        var calls = 0
        delivery.attach { calls += 1 }
        delivery.invalidate()
        delivery.suspend()
        scheduler.runNext()
        XCTAssertEqual(calls, 0)
        delivery.resume()
        scheduler.runNext()
        XCTAssertEqual(calls, 1)
    }

    func testPendingWorkDoesNotRetainDelivery() {
        let scheduler = ManualScheduler()
        weak var weakDelivery: InputInvalidationDelivery?
        var calls = 0
        do {
            let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
            weakDelivery = delivery
            delivery.attach { calls += 1 }
            delivery.invalidate()
        }
        XCTAssertNil(weakDelivery)
        scheduler.runNext()
        XCTAssertEqual(calls, 0)
    }
}

private final class ManualScheduler {
    private var pending: [() -> Void] = []

    var count: Int { pending.count }

    func enqueue(_ work: @escaping () -> Void) { pending.append(work) }

    func runNext() {
        precondition(!pending.isEmpty)
        pending.removeFirst()()
    }
}
#endif
