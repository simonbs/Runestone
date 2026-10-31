#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// Foreground integration coverage uses a key window, a public attachment and
/// synthetic AppKit events. It does not assert physical-device input behavior.
final class PublicAttachmentLiveInteractionTests: XCTestCase {
    func testResponderSelectionAndDocumentOwnedUndoRedo() throws {
        let fixture = try LivePublicFixture(text: "abcdef")
        defer { fixture.close() }
        try fixture.activate()
        XCTAssertTrue(NSApp.keyWindow === fixture.window)
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("moveRight:"), to: nil, from: nil))
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 1, length: 0))
        for _ in 0..<2 {
            XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("moveRightAndModifySelection:"), to: nil, from: nil))
        }
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 1, length: 2))
        try fixture.sendKey("x", keyCode: 7)
        XCTAssertEqual(fixture.host.text, "axdef")
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 2, length: 0))

        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("undo:"), to: nil, from: nil))
        XCTAssertTrue(fixture.wait(until: { fixture.host.text == "abcdef" && fixture.attachment.isEditable }))
        try fixture.focus()
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("redo:"), to: nil, from: nil))
        XCTAssertTrue(fixture.wait(until: { fixture.host.text == "axdef" && fixture.attachment.isEditable }))
        let history = fixture.host.completions.filter { $0.kind == .historyCommand }
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.map(\.outcome), [.completed, .completed])
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
    }

    func testResponderClipboardActionsUseIsolatedNamedPasteboard() throws {
        let fixture = try LivePublicFixture(text: "abc\r\ndef")
        defer { fixture.close() }
        try fixture.activate()
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        fixture.responder.inputPasteboardProvider = { board }
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("selectAll:"), to: nil, from: nil))
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 0, length: 8))
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("copy:"), to: nil, from: nil))
        XCTAssertEqual(board.string(forType: .string), "abc\r\ndef")
        XCTAssertEqual(fixture.host.text, "abc\r\ndef")
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("cut:"), to: nil, from: nil))
        XCTAssertEqual(fixture.host.text, "")
        XCTAssertEqual(board.string(forType: .string), "abc\r\ndef")
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("paste:"), to: nil, from: nil))
        XCTAssertEqual(fixture.host.text, "abc\r\ndef")
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 8, length: 0))
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
    }

    func testMouseDragAndBoundedAutoscrollThroughWindowEvents() throws {
        let fixture = try LivePublicFixture(text: String(repeating: "abcdefghijklmno\n", count: 100))
        defer { fixture.close() }
        try fixture.activate()
        // Control time and pending work while exercising the same responder
        // and viewport step in a key window through actual mouse events.
        fixture.responder.inputViewportClock = { 0 }
        let scheduler = LiveAutoscrollScheduler()
        let clock = PreparedInputAutoscrollClock(maximumFrames: 1, now: { 0 }, enqueue: scheduler.enqueue) {
            [weak responder = fixture.responder, weak window = fixture.window] point in
            guard let responder = responder, let window = window else { return false }
            return responder.performPointerAutoscrollStep(at: point, hasFocus: {
                window.isKeyWindow && window.firstResponder === responder
            })
        }
        fixture.responder.installPointerAutoscrollClock(clock)

        let start = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 2, in: fixture.responder))
        try sendMouse(.leftMouseDown, atScreen: NSPoint(x: start.midX, y: start.midY), fixture: fixture)
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 2, length: 0))
        let end = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 5, in: fixture.responder))
        try sendMouse(.leftMouseDragged, atScreen: NSPoint(x: end.midX, y: end.midY), fixture: fixture)
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 2, length: 3))

        let viewport = try XCTUnwrap(fixture.responder.visibleLayout?.viewport)
        let documentCaret = fixture.responder.convert(fixture.window.convertFromScreen(start), from: nil)
        let outsideDocument = NSPoint(x: documentCaret.midX, y: viewport.maxY + 48)
        let outsideWindow = fixture.responder.convert(outsideDocument, to: nil)
        let outsideScreen = fixture.window.convertPoint(toScreen: outsideWindow)
        try sendMouse(.leftMouseDragged, atScreen: outsideScreen, fixture: fixture)
        let beforeBounds = fixture.scroll.contentView.bounds
        let beforeSelection = try XCTUnwrap(fixture.attachment.inputState?.selection)
        XCTAssertEqual(scheduler.pendingCount, 1)
        scheduler.fireNext()
        XCTAssertGreaterThan(fixture.scroll.contentView.bounds.minY, beforeBounds.minY)
        let afterSelection = try XCTUnwrap(fixture.attachment.inputState?.selection)
        XCTAssertEqual(afterSelection.location, 2)
        XCTAssertGreaterThan(afterSelection.length, beforeSelection.length)
        XCTAssertEqual(scheduler.pendingCount, 0, "one-frame budget must stop scheduling")
        XCTAssertFalse(clock.isRunning)
        try sendMouse(.leftMouseUp, atScreen: outsideScreen, fixture: fixture)
        XCTAssertEqual(scheduler.pendingCount, 0)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
    }

    func testKeyWindowTransferKeepsPublicAttachmentsIsolated() throws {
        let first = try LivePublicFixture(text: "first")
        defer { first.close() }
        try first.activate()
        try first.sendKey("a", keyCode: 0)
        XCTAssertEqual(first.host.text, "afirst")

        let second = try LivePublicFixture(text: "second")
        defer { second.close() }
        try second.activate()
        XCTAssertTrue(second.window.isKeyWindow)
        XCTAssertFalse(first.window.isKeyWindow)
        try second.sendKey("b", keyCode: 11)
        XCTAssertEqual(second.host.text, "bsecond")
        try first.sendKey("x", keyCode: 7)
        XCTAssertEqual(first.host.text, "afirst", "a non-key view must reject the event")
        XCTAssertEqual(second.host.text, "bsecond")

        first.window.makeKeyAndOrderFront(nil)
        XCTAssertTrue(first.wait(until: { first.window.isKeyWindow && !second.window.isKeyWindow }))
        try first.focus()
        try first.sendKey("c", keyCode: 8)
        XCTAssertEqual(first.host.text, "acfirst")
        XCTAssertEqual(second.host.text, "bsecond")
        XCTAssertEqual(first.host.parentStarts, first.host.parentCloses)
        XCTAssertEqual(second.host.parentStarts, second.host.parentCloses)
    }

    private func sendMouse(_ type: NSEvent.EventType, atScreen point: NSPoint, fixture: LivePublicFixture) throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
            location: fixture.window.convertPoint(fromScreen: point), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: fixture.window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
        fixture.window.sendEvent(event)
    }
}

private final class LiveAutoscrollScheduler {
    private var work: (() -> Void)?
    var pendingCount: Int { work == nil ? 0 : 1 }
    func enqueue(_ delay: TimeInterval, _ body: @escaping () -> Void) -> () -> Void {
        XCTAssertNil(work, "at most one autoscroll tick may be pending")
        work = body
        return { [weak self] in self?.work = nil }
    }
    func fireNext() {
        guard let pending = work else { XCTFail("Expected an autoscroll tick"); return }
        work = nil
        pending()
    }
}
#endif
