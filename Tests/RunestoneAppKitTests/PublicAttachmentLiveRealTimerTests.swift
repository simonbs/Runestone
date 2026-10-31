#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// Uses the production run-loop timer and uptime with the app's 720×480 clip.
/// NSEvents are synthetic; no claim is made about physical mouse input.
final class PublicAttachmentLiveRealTimerTests: XCTestCase {
    func testHeldDragAdvancesAndMouseUpStopsRealTimer() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let drag = try beginHeldDrag(fixture)
        try waitForAdvance(fixture, drag: drag)
        try waitForAdditionalAdvances(fixture, count: 3)
        try mouse(.leftMouseUp, screen: drag.outside, fixture: fixture)
        let stopped = fixture.scroll.contentView.bounds
        let selected = try XCTUnwrap(fixture.attachment.inputState?.selection)
        try waitForTimerTurn()
        XCTAssertEqual(fixture.scroll.contentView.bounds, stopped)
        XCTAssertEqual(fixture.attachment.inputState?.selection, selected)
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
    }

    func testFocusLossStopsRealTimer() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let drag = try beginHeldDrag(fixture)
        try waitForAdvance(fixture, drag: drag)
        let childStarts = fixture.host.childStarts
        let publications = fixture.host.publications
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.other))
        XCTAssertTrue(fixture.window.firstResponder === fixture.other)
        // Reconstruction after focus loss can independently adjust the clip.
        // Wait for the public attachment and its viewport to settle first.
        XCTAssertTrue(fixture.wait(until: {
            fixture.attachment.isEditable && fixture.responder.visibleLayout?.isComplete == true &&
                fixture.responder.visibleLayout?.viewport == fixture.scroll.contentView.bounds
        }))
        let turn = XCTestExpectation(description: "focus-loss reconstruction completes")
        DispatchQueue.main.async { turn.fulfill() }
        XCTAssertEqual(XCTWaiter().wait(for: [turn], timeout: 3), .completed)
        XCTAssertEqual(fixture.host.childStarts, childStarts)
        let stopped = fixture.scroll.contentView.bounds
        try waitForTimerTurn()
        XCTAssertEqual(fixture.scroll.contentView.bounds, stopped)
        XCTAssertEqual(fixture.host.publications, publications)
        XCTAssertEqual(fixture.host.childStarts, childStarts)
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
    }

    func testDetachmentStopsRealTimer() throws {
        let fixture = try makeFixture()
        defer { fixture.close() }
        let drag = try beginHeldDrag(fixture)
        try waitForAdvance(fixture, drag: drag)
        let publications = fixture.host.publications
        let childStarts = fixture.host.childStarts
        _ = fixture.attachment.detach()
        XCTAssertFalse(fixture.attachment.isEditable)
        XCTAssertTrue(fixture.wait(until: { fixture.attachment.detach() }))
        let stopped = fixture.scroll.contentView.bounds
        try waitForTimerTurn()
        XCTAssertEqual(fixture.scroll.contentView.bounds, stopped)
        XCTAssertEqual(fixture.host.publications, publications)
        XCTAssertEqual(fixture.host.childStarts, childStarts)
        XCTAssertFalse(fixture.attachment.requestFirstResponder())
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
    }

    private struct Drag {
        let outside: NSPoint
        let originalBounds: NSRect
        let originalSelection: NSRange
        let completionCount: Int
    }

    private func makeFixture() throws -> LivePublicFixture {
        let fixture = try LivePublicFixture(text: String(repeating: "abcdefghijklmno\n", count: 100),
                                            font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular))
        fixture.window.setContentSize(NSSize(width: 720, height: 520))
        fixture.scroll.frame = NSRect(x: 0, y: 40, width: 720, height: 480)
        fixture.scroll.tile()
        fixture.responder.updateViewport()
        return fixture
    }

    private func beginHeldDrag(_ fixture: LivePublicFixture) throws -> Drag {
        try fixture.activate()
        XCTAssertEqual(fixture.scroll.contentView.bounds.size, NSSize(width: 720, height: 480))
        let view = fixture.attachment.view
        let first = view.accessibilityFrame(for: NSRange(location: 2, length: 1))
        XCTAssertFalse(first.isEmpty)
        try mouse(.leftMouseDown, screen: NSPoint(x: first.minX + 0.1, y: first.midY), fixture: fixture)
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 2, length: 0))
        let second = view.accessibilityFrame(for: NSRange(location: 5, length: 1))
        XCTAssertFalse(second.isEmpty)
        try mouse(.leftMouseDragged, screen: NSPoint(x: second.minX + 0.1, y: second.midY), fixture: fixture)
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 2, length: 3))
        let clip = fixture.scroll.contentView
        let edge = NSPoint(x: clip.bounds.midX, y: clip.bounds.maxY + 48)
        let outside = fixture.window.convertPoint(toScreen: clip.convert(edge, to: nil))
        let bounds = clip.bounds
        try mouse(.leftMouseDragged, screen: outside, fixture: fixture)
        XCTAssertTrue(fixture.window.isKeyWindow)
        XCTAssertTrue(fixture.window.firstResponder === fixture.responder)
        XCTAssertTrue(fixture.attachment.isEditable)
        let selection = try XCTUnwrap(fixture.attachment.inputState?.selection)
        return Drag(outside: outside, originalBounds: bounds, originalSelection: selection,
                    completionCount: fixture.host.completions.count)
    }

    private func waitForAdvance(_ fixture: LivePublicFixture, drag: Drag) throws {
        // A bounds notification observes the first real timer step without
        // polling for a second and accidentally reaching the document edge.
        let progressed = XCTNSNotificationExpectation(name: NSView.boundsDidChangeNotification,
                                                      object: fixture.scroll.contentView)
        progressed.handler = { _ in fixture.scroll.contentView.bounds.minY > drag.originalBounds.minY }
        let result = XCTWaiter().wait(for: [progressed], timeout: 3)
        XCTAssertEqual(result, .completed, "Real-timer drag did not advance; bounds=\(fixture.scroll.contentView.bounds), completions=\(fixture.host.completions.dropFirst(drag.completionCount))")
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, drag.originalBounds.minY)
        let state = try XCTUnwrap(fixture.attachment.inputState, "Input became unavailable after a drag tick")
        XCTAssertGreaterThan(state.selection.length, drag.originalSelection.length)
        XCTAssertEqual(state.selection.location, 2)
        XCTAssertTrue(fixture.window.isKeyWindow)
        XCTAssertTrue(fixture.window.firstResponder === fixture.responder)
        XCTAssertTrue(fixture.attachment.isEditable)
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
    }

    private func waitForAdditionalAdvances(_ fixture: LivePublicFixture, count: Int) throws {
        let startingY = fixture.scroll.contentView.bounds.minY
        let startingSelection = try XCTUnwrap(fixture.attachment.inputState?.selection)
        var advances: [CGFloat] = []
        let progress = XCTNSNotificationExpectation(name: NSView.boundsDidChangeNotification,
                                                    object: fixture.scroll.contentView)
        progress.handler = { _ in
            let currentY = fixture.scroll.contentView.bounds.minY
            if currentY > (advances.last ?? startingY) { advances.append(currentY) }
            return advances.count >= count
        }
        let result = XCTWaiter().wait(for: [progress], timeout: 3)
        XCTAssertEqual(result, .completed, "Expected \(count) additional real-timer scroll steps; observed \(advances), completions=\(fixture.host.completions)")
        XCTAssertEqual(advances.count, count)
        let selection = try XCTUnwrap(fixture.attachment.inputState?.selection)
        XCTAssertGreaterThan(selection.length, startingSelection.length)
        XCTAssertFalse(fixture.host.completions.contains { $0.outcome == .mayHaveApplied })
        XCTAssertTrue(fixture.window.isKeyWindow)
        XCTAssertTrue(fixture.window.firstResponder === fixture.responder)
    }

    private func waitForTimerTurn() throws {
        let settled = XCTestExpectation(description: "later production timer turn")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { settled.fulfill() }
        XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: 2), .completed)
    }

    private func mouse(_ type: NSEvent.EventType, screen: NSPoint, fixture: LivePublicFixture) throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
            location: fixture.window.convertPoint(fromScreen: screen), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: fixture.window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
        fixture.window.sendEvent(event)
    }
}
#endif
