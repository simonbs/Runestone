#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// Exercises the real common-mode timer and uptime in an AppKit window without
/// a key-window requirement. The internal attachment is resumed explicitly and
/// the timer step receives `hasFocus: { true }`; this cannot prove actual focus.
final class PreparedInputRealTimerIntegrationTests: XCTestCase {
    func testRealTimerAdvancesSeveralTimesAndMouseUpStopsIt() throws {
        let fixture = try RealTimerIntegrationFixture()
        defer { fixture.close() }
        let outside = try startDragging(fixture, requiredTicks: 3)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp,
            location: fixture.window.convertPoint(fromScreen: outside), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: fixture.window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        fixture.view.mouseUp(with: event)
        try assertTimerStopped(fixture)
    }

    func testRealTimerStopsOnFocusLoss() throws {
        let fixture = try RealTimerIntegrationFixture()
        defer { fixture.close() }
        _ = try startDragging(fixture, requiredTicks: 1)
        let selection = fixture.attachment.adapter.selectedRangeForInput()
        let childStarts = fixture.host.childStarts
        fixture.view.revokeFocusEligibility()
        XCTAssertFalse(fixture.clock.isRunning, "Focus loss must cancel the clock immediately")
        // Focus loss reconstructs the canonical snapshot and can legitimately
        // adjust the clip while line heights settle. Wait for that independent
        // work before measuring whether the cancelled timer moves anything.
        let reconnected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            fixture.connection.isConnectedForEditing &&
                fixture.view.visibleLayout?.isComplete == true &&
                fixture.view.visibleLayout?.viewport == fixture.scroll.contentView.bounds
        }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [reconnected], timeout: 3), .completed)
        let turn = XCTestExpectation(description: "reconstruction completes its main-queue work")
        DispatchQueue.main.async { turn.fulfill() }
        XCTAssertEqual(XCTWaiter().wait(for: [turn], timeout: 3), .completed)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), selection)
        XCTAssertEqual(fixture.host.childStarts, childStarts)
        try assertTimerStopped(fixture)
    }

    func testRealTimerStopsOnDetachment() throws {
        let fixture = try RealTimerIntegrationFixture()
        defer { fixture.close() }
        _ = try startDragging(fixture, requiredTicks: 1)
        fixture.view.disarmForDetachment()
        try assertTimerStopped(fixture)
    }

    private func startDragging(_ fixture: RealTimerIntegrationFixture, requiredTicks: Int) throws -> NSPoint {
        let clip = fixture.scroll.contentView
        let start = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 2, in: fixture.view))
        let startPoint = NSPoint(x: start.midX, y: start.midY)
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.view.beginPointerSelection(at: startPoint, extending: false,
                                               connection: fixture.connection, hasFocus: { true })
        })
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), NSRange(location: 2, length: 0))

        let end = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 5, in: fixture.view))
        var applied = false
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            applied = fixture.view.continuePointerSelection(at: NSPoint(x: end.midX, y: end.midY),
                                                            connection: fixture.connection, hasFocus: { true })
        })
        XCTAssertTrue(applied)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), NSRange(location: 2, length: 3))

        let initialY = clip.bounds.minY
        var advances: [CGFloat] = []
        let progressed = XCTNSNotificationExpectation(name: NSView.boundsDidChangeNotification, object: clip)
        progressed.handler = { _ in
            let y = clip.bounds.minY
            if y > (advances.last ?? initialY) { advances.append(y) }
            return advances.count >= requiredTicks
        }
        let edge = NSPoint(x: clip.bounds.midX, y: clip.bounds.maxY + 48)
        let outside = fixture.window.convertPoint(toScreen: clip.convert(edge, to: nil))
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            applied = fixture.view.continuePointerSelection(at: outside, connection: fixture.connection, hasFocus: { true })
        })
        XCTAssertTrue(applied)
        let before = fixture.attachment.adapter.selectedRangeForInput()
        XCTAssertTrue(fixture.clock.isRunning)
        let result = XCTWaiter().wait(for: [progressed], timeout: 3)
        XCTAssertEqual(result, .completed, "Expected \(requiredTicks) real-timer scroll steps; advances=\(advances), completions=\(fixture.host.completions)")
        XCTAssertEqual(advances.count, requiredTicks)
        XCTAssertGreaterThan(clip.bounds.minY, initialY)
        let after = fixture.attachment.adapter.selectedRangeForInput()
        XCTAssertEqual(after.location, 2)
        XCTAssertGreaterThan(after.length, before.length)
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
        XCTAssertTrue(fixture.connection.isActiveForInput)
        XCTAssertTrue(fixture.clock.isRunning, "A subsequent real timer tick must be pending before stopping")
        return outside
    }

    private func assertTimerStopped(_ fixture: RealTimerIntegrationFixture) throws {
        XCTAssertFalse(fixture.clock.isRunning)
        let stopped = fixture.scroll.contentView.bounds
        let selection = fixture.attachment.adapter.selectedRangeForInput()
        let publications = fixture.host.publications
        let childStarts = fixture.host.childStarts
        let settled = XCTestExpectation(description: "one later real timer interval")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: 2), .completed)
        XCTAssertEqual(fixture.scroll.contentView.bounds, stopped)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), selection)
        XCTAssertEqual(fixture.host.publications, publications)
        XCTAssertEqual(fixture.host.childStarts, childStarts)
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
    }
}

private final class RealTimerIntegrationFixture {
    let host: LivePublicHost
    let attachment: PreparedInputDocumentAttachment
    let connection: PreparedInputContextConnection
    let view: PreparedInputResponderView
    let window: NSWindow
    let scroll: NSScrollView
    let clock: PreparedInputAutoscrollClock

    init() throws {
        _ = NSApplication.shared
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let host = LivePublicHost(text: String(repeating: "abcdefghijklmno\n", count: 100), font: font)
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 720, height: 480),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: try XCTUnwrap(window.contentView).bounds)
        window.contentView?.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        let clock = PreparedInputAutoscrollClock { [weak view] point in
            view?.performPointerAutoscrollStep(at: point, hasFocus: { true }) ?? false
        }
        view.installPointerAutoscrollClock(clock)
        self.host = host
        self.attachment = attachment
        self.connection = connection
        self.view = view
        self.window = window
        self.scroll = scroll
        self.clock = clock
        XCTAssertFalse(window.isKeyWindow)
        XCTAssertEqual(scroll.contentView.bounds.size, NSSize(width: 720, height: 480))
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
        XCTAssertTrue(connection.isActiveForInput)
    }

    func close() {
        let detached = XCTestExpectation(description: "internal attachment detaches")
        var attempts = 0
        func retry() {
            if self.attachment.disconnect() { detached.fulfill(); return }
            attempts += 1
            if attempts >= 100 { XCTFail("Attachment did not detach"); detached.fulfill(); return }
            DispatchQueue.main.async(execute: retry)
        }
        retry()
        XCTAssertEqual(XCTWaiter().wait(for: [detached], timeout: 3), .completed)
        window.close()
    }
}
#endif
