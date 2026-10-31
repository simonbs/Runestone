#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class InputInvalidationIntegrationTests: XCTestCase {
    func testSelectionScrollResizeAndWindowMoveInvalidateCoordinates() {
        let scheduler = QueuedScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let text = NSAttributedString(string: String(repeating: "line\n", count: 30), attributes: [.font: NSFont.systemFont(ofSize: 16)])
        let view = ReadOnlyDocumentView(snapshot: text, fallbackHeight: 16, inputInvalidation: delivery)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let session = DocumentInputSession(view: view)
        var calls = 0
        delivery.attach { calls += 1 }

        XCTAssertTrue(session.setSelection(NSRange(location: 2, length: 0)))
        scheduler.runAll()
        XCTAssertGreaterThan(calls, 0)
        var previous = calls
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 20))
        waitForViewportRetry()
        scheduler.runAll()
        XCTAssertGreaterThan(calls, previous)
        previous = calls
        scroll.setFrameSize(NSSize(width: 140, height: 80))
        scroll.tile()
        view.updateViewport()
        waitForViewportRetry()
        scheduler.runAll()
        XCTAssertGreaterThan(calls, previous)
        previous = calls
        window.setFrameOrigin(NSPoint(x: 140, y: 130))
        scheduler.runAll()
        XCTAssertGreaterThan(calls, previous)

        delivery.detach()
        previous = calls
        XCTAssertTrue(session.setSelection(NSRange(location: 3, length: 0)))
        scheduler.runAll()
        XCTAssertEqual(calls, previous)
    }

    private func waitForViewportRetry() {
        let finished = expectation(description: "viewport retry")
        DispatchQueue.main.async { finished.fulfill() }
        wait(for: [finished], timeout: 2)
    }

    func testUnchangedLayoutDuringDeliveryDoesNotReschedule() {
        let scheduler = QueuedScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 120, height: 60))
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: "hello", attributes: [.font: NSFont.systemFont(ofSize: 16)]),
                                        fallbackHeight: 16, inputInvalidation: delivery)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        var calls = 0
        delivery.attach { [weak view] in
            calls += 1
            view?.updateViewport()
        }
        view.noteInputCoordinatesChanged()
        scheduler.runAll()
        XCTAssertEqual(calls, 1)
    }

    func testGeometryUnavailableDuringSynchronousResize() {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: String(repeating: "words ", count: 100),
                                                                     attributes: [.font: NSFont.systemFont(ofSize: 16)]))
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        var observed = false
        view.postsFrameChangedNotifications = true
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard view.updatingViewport else { return }
            observed = true
            view.updateViewport() // Reentrant request with unchanged clip bounds needs no retry.
            XCTAssertNil(InputScreenCaretGeometry.rect(at: 0, in: view))
            XCTAssertNil(InputScreenRangeGeometry.firstRect(for: NSRange(location: 0, length: 1), in: view))
            XCTAssertNil(InputScreenRangeGeometry.characterIndex(for: .zero, in: view))
        }
        scroll.setFrameSize(NSSize(width: 80, height: 80))
        scroll.tile()
        view.updateViewport()
        NotificationCenter.default.removeObserver(observer)
        XCTAssertTrue(observed)
        XCTAssertNotNil(InputScreenCaretGeometry.rect(at: 0, in: view))
    }

    func testOldWindowStopsInvalidatingAfterReattachment() {
        let scheduler = QueuedScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        let oldWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 120, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        let newWindow = NSWindow(contentRect: NSRect(x: 300, y: 100, width: 120, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: oldWindow.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: ""), fallbackHeight: 16, inputInvalidation: delivery)
        oldWindow.contentView!.addSubview(scroll)
        scroll.documentView = view
        var calls = 0
        delivery.attach { calls += 1 }
        scroll.removeFromSuperview()
        newWindow.contentView!.addSubview(scroll)
        scheduler.runAll()
        let previous = calls
        NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: oldWindow)
        scheduler.runAll()
        XCTAssertEqual(calls, previous)
        NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: newWindow)
        scheduler.runAll()
        XCTAssertGreaterThan(calls, previous)
    }

    func testDeliveryWaitsUntilInputChangeCallbackReturns() {
        let scheduler = QueuedScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: ""), fallbackHeight: 16, inputInvalidation: delivery)
        let session = DocumentInputSession(view: view)
        var calls = 0
        delivery.attach { calls += 1 }
        view.noteInputCoordinatesChanged()
        session.contentDidChange = { _ in
            scheduler.runAll()
            XCTAssertEqual(calls, 0)
            XCTAssertEqual(session.selectedRange, NSRange(location: 1, length: 0))
        }
        XCTAssertTrue(session.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0), attributes: [:]))
        scheduler.runAll()
        XCTAssertEqual(calls, 1)
    }

    func testNestedResizeSchedulesAnotherViewportTransaction() {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: String(repeating: "words ", count: 100),
                                                                     attributes: [.font: NSFont.systemFont(ofSize: 16)]))
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        view.postsFrameChangedNotifications = true
        let notified = expectation(description: "invalidation after retry")
        notified.assertForOverFulfill = false
        var checked = false
        view.inputInvalidation.attach { [weak view, weak scroll] in
            guard !checked, let view = view, let scroll = scroll else { return }
            checked = true
            XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
            notified.fulfill()
        }
        var resized = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard view.updatingViewport, !resized else { return }
            resized = true
            scroll.setFrameSize(NSSize(width: 80, height: 80))
            scroll.tile()
        }
        scroll.setFrameSize(NSSize(width: 140, height: 80))
        scroll.tile()
        view.updateViewport()
        let finished = expectation(description: "deferred viewport retry")
        DispatchQueue.main.async { finished.fulfill() }
        wait(for: [finished, notified], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
        view.inputInvalidation.detach()
        XCTAssertTrue(resized)
        XCTAssertEqual(view.frame.width, scroll.contentView.bounds.width, accuracy: 0.01)
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
    }

    func testRepeatedReentrantResizesDoNotHoldInvalidationForever() {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: String(repeating: "words ", count: 100),
                                                                     attributes: [.font: NSFont.systemFont(ofSize: 16)]))
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let notified = expectation(description: "bounded invalidation")
        notified.assertForOverFulfill = false
        view.inputInvalidation.attach { notified.fulfill() }
        view.postsFrameChangedNotifications = true
        var changes = 0
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard view.updatingViewport, changes < 20 else { return }
            changes += 1
            scroll.setFrameSize(NSSize(width: changes.isMultiple(of: 2) ? 80 : 140, height: 80))
            scroll.tile()
        }
        scroll.setFrameSize(NSSize(width: 140, height: 80))
        scroll.tile()
        view.updateViewport()
        wait(for: [notified], timeout: 2)
        let settledChanges = changes
        for _ in 0..<4 { waitForViewportRetry() }
        XCTAssertEqual(changes, settledChanges)
        NotificationCenter.default.removeObserver(observer)
        XCTAssertGreaterThan(changes, 0)
        XCTAssertLessThanOrEqual(changes, 8)
        // The observer has stopped. Recovery must not require another resize.
        let recovered = expectation(description: "stable geometry recovers")
        view.inputInvalidation.attach { [weak view, weak scroll] in
            guard let view = view, let scroll = scroll, view.visibleLayout?.viewport == scroll.contentView.bounds else { return }
            recovered.fulfill()
        }
        wait(for: [recovered], timeout: 2)
        view.inputInvalidation.detach()
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
    }

    func testNewExhaustionSupersedesAnOlderRecoveryTimer() {
        let scheduler = RecoveryScheduler()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: String(repeating: "words ", count: 100),
                                                                      attributes: [.font: NSFont.systemFont(ofSize: 16)]),
                                        fallbackHeight: 16, viewportRecoveryScheduler: scheduler.enqueue)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        view.postsFrameChangedNotifications = true
        var changes = 0
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard view.updatingViewport else { return }
            changes += 1
            scroll.setFrameSize(NSSize(width: changes.isMultiple(of: 2) ? 80 : 140, height: 80))
            scroll.tile()
        }
        scroll.setFrameSize(NSSize(width: 140, height: 80))
        scroll.tile()
        view.updateViewport()
        for _ in 0..<4 { waitForViewportRetry() }
        XCTAssertEqual(scheduler.count, 1)
        view.noteInputCoordinatesChanged() // A new external geometry event.
        view.updateViewport()
        for _ in 0..<4 { waitForViewportRetry() }
        XCTAssertEqual(scheduler.count, 2)
        NotificationCenter.default.removeObserver(observer)
        scheduler.runNext()
        XCTAssertNil(view.visibleLayout)
        scheduler.runNext()
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
    }

    func testCoordinateOnlyChangeDoesNotCancelViewportRecovery() {
        let scheduler = RecoveryScheduler()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: String(repeating: "words ", count: 100),
                                                                      attributes: [.font: NSFont.systemFont(ofSize: 16)]),
                                        fallbackHeight: 16, viewportRecoveryScheduler: scheduler.enqueue)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        view.postsFrameChangedNotifications = true
        var changes = 0
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard view.updatingViewport else { return }
            changes += 1
            scroll.setFrameSize(NSSize(width: changes.isMultiple(of: 2) ? 80 : 140, height: 80))
            scroll.tile()
        }
        scroll.setFrameSize(NSSize(width: 140, height: 80))
        scroll.tile()
        view.updateViewport()
        for _ in 0..<4 { waitForViewportRetry() }
        XCTAssertEqual(scheduler.count, 1)
        XCTAssertNil(view.visibleLayout)
        NotificationCenter.default.removeObserver(observer)
        view.noteInputCoordinatesChanged() // Selection or window movement without a bounds change.
        scheduler.runNext() // The superseded timer is inert.
        waitForViewportRetry()
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
    }

    func testContentReplacementDuringLayoutRetriesBeforeInvalidation() {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let original = NSAttributedString(string: String(repeating: "line\n", count: 100), attributes: [.font: NSFont.systemFont(ofSize: 16)])
        let view = ReadOnlyDocumentView(content: original)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let notified = expectation(description: "geometry follows nested replacement")
        notified.assertForOverFulfill = false
        var checked = false
        view.inputInvalidation.attach { [weak view, weak scroll] in
            guard !checked, let view = view, let scroll = scroll else { return }
            checked = true
            XCTAssertEqual(view.content.string, "foreign")
            XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
            notified.fulfill()
        }
        view.postsFrameChangedNotifications = true
        var replaced = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard view.updatingViewport, !replaced else { return }
            replaced = true
            view.setContent(NSAttributedString(string: "foreign"))
        }
        view.setContent(NSAttributedString(string: "short"))
        wait(for: [notified], timeout: 2)
        NotificationCenter.default.removeObserver(observer)
        view.inputInvalidation.detach()
        XCTAssertTrue(replaced)
    }

    func testFractionalConstrainedScrollPublishesActualViewport() {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        let clip = FractionalClipView(frame: scroll.contentView.frame)
        scroll.contentView = clip
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: String(repeating: "line\n", count: 100),
                                                                     attributes: [.font: NSFont.systemFont(ofSize: 16)]))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        clip.scroll(to: NSPoint(x: 0, y: 100))
        view.updateViewport()
        XCTAssertGreaterThan(clip.bounds.minY, 1)
        clip.adjustsOrigin = true
        view.updateViewport()
        XCTAssertGreaterThan(clip.adjustmentCount, 0)
        XCTAssertEqual(view.visibleLayout?.viewport, clip.bounds)
        XCTAssertNotNil(view.visibleLayout)
    }

    func testPendingRetryReleasesSuspensionAfterViewDeallocation() {
        let scheduler = QueuedScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 180, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        weak var weakView: ReadOnlyDocumentView?
        var resized = false
        autoreleasepool {
            let scroll = NSScrollView(frame: window.contentView!.bounds)
            let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: String(repeating: "words ", count: 100),
                                                                          attributes: [.font: NSFont.systemFont(ofSize: 16)]),
                                            fallbackHeight: 16, inputInvalidation: delivery)
            weakView = view
            window.contentView!.addSubview(scroll)
            scroll.documentView = view
            scroll.tile()
            view.updateViewport()
            view.postsFrameChangedNotifications = true
            let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { [weak view, weak scroll] _ in
                guard let view = view, let scroll = scroll, view.updatingViewport, !resized else { return }
                resized = true
                scroll.setFrameSize(NSSize(width: 80, height: 80))
                scroll.tile()
            }
            scroll.setFrameSize(NSSize(width: 140, height: 80))
            scroll.tile()
            view.updateViewport()
            NotificationCenter.default.removeObserver(observer)
            scroll.documentView = nil
            scroll.removeFromSuperview()
        }
        XCTAssertTrue(resized)
        XCTAssertNil(weakView)
        waitForViewportRetry()
        var calls = 0
        delivery.attach { calls += 1 }
        delivery.invalidate()
        scheduler.runAll()
        XCTAssertEqual(calls, 1)
    }

    func testMarkedStateOnlyChangeAndReentrantInvalidationAreDelivered() {
        let scheduler = QueuedScheduler()
        let delivery = InputInvalidationDelivery(schedule: scheduler.enqueue)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: ""), fallbackHeight: 16, inputInvalidation: delivery)
        let session = DocumentInputSession(view: view)
        XCTAssertTrue(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                            replacementRange: NSRange(location: NSNotFound, length: 0), attributes: [:]))
        var calls = 0
        delivery.attach { [weak view] in
            calls += 1
            if calls == 1 { view?.noteInputCoordinatesChanged() }
        }
        XCTAssertTrue(session.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0), attributes: [:]))
        XCTAssertNil(session.markedRange)
        scheduler.runAll()
        XCTAssertEqual(calls, 2)
    }
}

private final class RecoveryScheduler {
    private var pending: [() -> Void] = []
    var count: Int { pending.count }
    func enqueue(_ delay: TimeInterval, _ work: @escaping () -> Void) { pending.append(work) }
    func runNext() {
        precondition(!pending.isEmpty)
        pending.removeFirst()()
    }
}

private final class FractionalClipView: NSClipView {
    var adjustsOrigin = false
    var adjustmentCount = 0
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var result = super.constrainBoundsRect(proposedBounds)
        if adjustsOrigin && result.minY > 1 {
            result.origin.y += 0.001
            adjustmentCount += 1
        }
        return result
    }
}

private final class QueuedScheduler {
    private var pending: [() -> Void] = []
    func enqueue(_ work: @escaping () -> Void) { pending.append(work) }
    func runAll() {
        var iterations = 0
        while !pending.isEmpty {
            iterations += 1
            guard iterations < 20 else { XCTFail("Invalidation queue did not settle"); return }
            pending.removeFirst()()
        }
    }
}
#endif
