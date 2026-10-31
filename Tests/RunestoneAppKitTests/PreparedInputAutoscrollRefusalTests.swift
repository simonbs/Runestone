#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// A timer step is its own admitted dispatch. A refusal that is proven to
/// precede viewport and selection work is a normal stop, not an uncertain edit.
final class PreparedInputAutoscrollRefusalTests: XCTestCase {
    func testLongNearbyLineStopsBeforeScrollWithoutUncertainDispatch() throws {
        let text = String(repeating: "short\n", count: 12) + String(repeating: "x", count: 5_000) + "\nlast"
        let fixture = try RefusalFixture(text: text)
        defer { fixture.close() }
        let point = try fixture.startDraggingOutside()
        let bounds = fixture.scroll.contentView.bounds
        let selection = fixture.attachment.adapter.selectedRangeForInput()
        let childStarts = fixture.host.childStarts
        fixture.view.inputViewportClock = { 0 }

        XCTAssertFalse(fixture.view.performPointerAutoscrollStep(at: point, hasFocus: { true }))
        XCTAssertEqual(fixture.scroll.contentView.bounds, bounds)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), selection)
        XCTAssertEqual(fixture.host.text, text)
        XCTAssertEqual(fixture.host.childStarts, childStarts)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .completed)
        XCTAssertTrue(fixture.attachment.connection.takeInputFailures().records.isEmpty)
        XCTAssertFalse(fixture.clock.isRunning)
    }

    func testPreflightCalloutThatChangesSelectionGenerationRemainsUncertain() throws {
        let text = String(repeating: "short\n", count: 12) + String(repeating: "x", count: 5_000) + "\nlast"
        let fixture = try RefusalFixture(text: text)
        defer { fixture.close() }
        let point = try fixture.startDraggingOutside()
        let bounds = fixture.scroll.contentView.bounds
        var clockCalls = 0
        fixture.view.inputViewportClock = {
            clockCalls += 1
            if clockCalls == 4 { fixture.view.invalidateInputSelectionTracking() }
            return 0
        }

        XCTAssertFalse(fixture.view.performPointerAutoscrollStep(at: point, hasFocus: { true }))
        XCTAssertGreaterThanOrEqual(clockCalls, 4)
        XCTAssertEqual(fixture.scroll.contentView.bounds, bounds)
        XCTAssertEqual(fixture.host.text, text)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        XCTAssertEqual(fixture.attachment.connection.takeInputFailures().records.last?.failure.effect, .mayHaveApplied)
    }

    func testOldTickDoesNotCancelNewGestureWithIdenticalSelection() throws {
        let text = String(repeating: "short\n", count: 12) + String(repeating: "x", count: 5_000) + "\nlast"
        let fixture = try RefusalFixture(text: text)
        defer { fixture.view.inputViewportClock = { 0 }; fixture.close() }
        let outside = try fixture.startDraggingOutside()
        let bounds = fixture.scroll.contentView.bounds
        let originalSelection = fixture.attachment.adapter.selectedRangeForInput()
        let originalRevision = fixture.view.inputSelectionRevision
        let endCaret = try XCTUnwrap(InputScreenCaretGeometry.rect(at: originalSelection.upperBound, in: fixture.view))
        let endDocument = fixture.view.convert(fixture.window.convertFromScreen(endCaret), from: nil)
        let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
        let endPoint = fixture.window.convertPoint(toScreen: fixture.view.convert(
            NSPoint(x: endDocument.midX, y: min(max(endDocument.midY, viewport.minY), viewport.maxY.nextDown)), to: nil))
        XCTAssertEqual(InputScreenRangeGeometry.characterIndexForPointer(for: endPoint, in: fixture.view),
                       originalSelection.upperBound)
        var calls = 0
        var restarted = false
        fixture.view.inputViewportClock = {
            calls += 1
            if calls == 4 {
                // Shift-click the current endpoint and drag to the same edge:
                // selected range, content and selection revision all stay the
                // same, but this is a different pointer gesture and clock.
                restarted = true
                fixture.view.beginPointerSelection(at: endPoint, extending: true,
                    connection: fixture.attachment.connection, hasFocus: { true })
                XCTAssertTrue(fixture.view.continuePointerSelection(at: outside,
                    connection: fixture.attachment.connection, hasFocus: { true }))
                XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), originalSelection)
                XCTAssertEqual(fixture.view.inputSelectionRevision, originalRevision)
                XCTAssertTrue(fixture.clock.isRunning)
            }
            return 0
        }

        XCTAssertFalse(fixture.view.performPointerAutoscrollStep(at: outside, hasFocus: { true }))
        XCTAssertTrue(restarted)
        XCTAssertEqual(fixture.scroll.contentView.bounds, bounds)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), originalSelection)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        XCTAssertEqual(fixture.attachment.connection.takeInputFailures().records.last?.failure.effect, .mayHaveApplied)
        XCTAssertTrue(fixture.clock.isRunning, "The old tick must not stop the new gesture's clock")

        let nextCaret = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 3, in: fixture.view))
        let nextPoint = NSPoint(x: nextCaret.midX, y: nextCaret.midY)
        var moved = false
        XCTAssertTrue(fixture.attachment.connection.performCoordinatedInput {
            moved = fixture.view.continuePointerSelection(at: nextPoint,
                connection: fixture.attachment.connection, hasFocus: { true })
        })
        XCTAssertTrue(moved)
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput(), NSRange(location: 2, length: 1))
    }

    func testInvalidationAfterScrollRemainsUncertain() throws {
        let text = String(repeating: "short\n", count: 100)
        let fixture = try RefusalFixture(text: text)
        defer { fixture.close() }
        let point = try fixture.startDraggingOutside()
        let bounds = fixture.scroll.contentView.bounds
        fixture.view.inputViewportClock = { 0 }
        let token = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
            object: fixture.scroll.contentView, queue: nil) { _ in fixture.view.invalidateInputSelectionTracking() }
        defer { NotificationCenter.default.removeObserver(token) }

        XCTAssertFalse(fixture.view.performPointerAutoscrollStep(at: point, hasFocus: { true }))
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, bounds.minY)
        XCTAssertEqual(fixture.host.text, text)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        XCTAssertEqual(fixture.attachment.connection.takeInputFailures().records.last?.failure.effect, .mayHaveApplied)
    }
}

private final class RefusalFixture {
    let host: LivePublicHost
    let attachment: PreparedInputDocumentAttachment
    let view: PreparedInputResponderView
    let window: NSWindow
    let scroll: NSScrollView
    let clock: PreparedInputAutoscrollClock
    let queue: RefusalQueue

    init(text: String) throws {
        _ = NSApplication.shared
        let host = LivePublicHost(text: text)
        let queue = RefusalQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { RefusalDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 240, height: 130),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: try XCTUnwrap(window.contentView).bounds)
        window.contentView?.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let clock = PreparedInputAutoscrollClock(now: { 0 }, enqueue: { _, _ in { } }, step: { _ in false })
        view.installPointerAutoscrollClock(clock)
        self.host = host
        self.attachment = attachment
        self.view = view
        self.window = window
        self.scroll = scroll
        self.clock = clock
        self.queue = queue
        XCTAssertTrue(attachment.connection.resumeForFocus())
        XCTAssertNotNil(view.visibleLayout)
    }

    func startDraggingOutside() throws -> NSPoint {
        let caret = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 2, in: view))
        let inside = NSPoint(x: caret.midX, y: caret.midY)
        XCTAssertTrue(attachment.connection.performCoordinatedInput {
            self.view.beginPointerSelection(at: inside, extending: false, connection: self.attachment.connection,
                                            hasFocus: { true })
        })
        let viewport = try XCTUnwrap(view.visibleLayout?.viewport)
        let documentCaret = view.convert(window.convertFromScreen(caret), from: nil)
        let outside = window.convertPoint(toScreen: view.convert(NSPoint(x: documentCaret.midX,
                                                                          y: viewport.maxY + 48), to: nil))
        XCTAssertTrue(attachment.connection.performCoordinatedInput {
            self.view.continuePointerSelection(at: outside, connection: self.attachment.connection,
                                               hasFocus: { true })
        })
        XCTAssertTrue(clock.isRunning)
        return outside
    }

    func close() {
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
        window.close()
    }
}

private final class RefusalDriver: PreparedInputContextConnection.Driver {
    let object = NSObject()
    init(_ client: NSTextInputClient) {}
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class RefusalQueue {
    private var work: [() -> Void] = []
    func enqueue(_ body: @escaping () -> Void) { work.append(body) }
    func runAll() {
        var turns = 0
        while !work.isEmpty && turns < 200 {
            turns += 1
            work.removeFirst()()
        }
        XCTAssertTrue(work.isEmpty)
    }
}
#endif
