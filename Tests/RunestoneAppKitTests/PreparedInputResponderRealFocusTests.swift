#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// Exercises a real AppKit input context in a key window. The synthetic key and
/// direct marked-text callback do not establish a real input method's behavior.
final class PreparedInputResponderRealFocusTests: XCTestCase {
    func testKeyWindowTextInputBlurAndFocusRestoration() throws {
        let app = NSApplication.shared
        let previousPolicy = app.activationPolicy()
        _ = app.setActivationPolicy(.regular)
        let host = FocusDocumentHost(text: "abc")
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge))
        let responder = attachment.view
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 320, height: 180),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 40, width: 320, height: 140))
        let other = FocusOtherView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
        container.addSubview(scroll)
        container.addSubview(other)
        scroll.documentView = responder
        window.contentView = container
        defer {
            window.orderOut(nil)
            window.close()
            _ = app.setActivationPolicy(previousPolicy)
        }
        app.activate()
        window.makeKeyAndOrderFront(nil)
        let becameKey = expectation(for: NSPredicate { _, _ in window.isKeyWindow }, evaluatedWith: nil)
        guard XCTWaiter().wait(for: [becameKey], timeout: 2) == .completed else {
            throw XCTSkip("The test process could not obtain a real key window in this session")
        }
        XCTAssertTrue(window.isKeyWindow)
        XCTAssertTrue(window.makeFirstResponder(responder))
        XCTAssertTrue(window.firstResponder === responder)
        let contextReady = expectation(for: NSPredicate { _, _ in responder.inputContext != nil }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [contextReady], timeout: 2), .completed)
        let oldContext = try XCTUnwrap(responder.inputContext)
        let oldClient = oldContext.client
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
        window.sendEvent(event)
        XCTAssertTrue(window.isKeyWindow)
        XCTAssertTrue(window.firstResponder === responder)
        XCTAssertEqual(host.text, "aabc")
        XCTAssertEqual(host.publications, 1)
        XCTAssertEqual(host.undoRegistrations, 1)
        XCTAssertTrue(host.undo.canUndo)

        oldClient.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(oldClient.hasMarkedText())
        XCTAssertEqual(responder.content.string, "aにabc")
        XCTAssertEqual(host.text, "aabc")
        XCTAssertTrue(window.makeFirstResponder(other))
        XCTAssertTrue(window.firstResponder === other)
        XCTAssertFalse(oldClient.hasMarkedText())
        oldClient.insertText("stale", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(host.text, "aabc")
        XCTAssertEqual(host.undoRegistrations, 1)

        XCTAssertTrue(window.makeFirstResponder(responder))
        XCTAssertTrue(window.firstResponder === responder)
        let freshContext = expectation(for: NSPredicate { _, _ in
            guard window.isKeyWindow, window.firstResponder === responder, let current = responder.inputContext else { return false }
            return current !== oldContext
        }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [freshContext], timeout: 3), .completed)
        XCTAssertEqual(responder.content.string, "aabc")
        XCTAssertEqual(oldClient.selectedRange().location, NSNotFound)
        XCTAssertFalse(oldClient.hasMarkedText())
        XCTAssertEqual(host.publications, 1)
        XCTAssertEqual(host.undoRegistrations, 1)
        host.undo.undo()
        XCTAssertEqual(host.text, "abc")
        XCTAssertFalse(host.undo.canUndo)
        withExtendedLifetime(oldContext) {}
    }
}

private final class FocusOtherView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

private final class FocusDocumentHost: NSObject, RunestoneInputDocumentHost {
    let bridge = RunestoneInputDocumentBridge()
    let lifetime = RunestoneInputDocumentLifetime()
    let undo = UndoManager()
    var text: String
    var inputRevision = UUID()
    var busy = false
    var publications = 0
    var undoRegistrations = 0

    init(text: String) {
        self.text = text
        super.init()
        undo.groupsByEvent = false
    }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !busy else { return .busy }
        guard inputRevision == expectedRevision else { return .stale }
        busy = true
        return .reserved(FocusEventReservation(host: self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(FocusReconstructionReservation(host: self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)]
    }
}

private final class FocusEventReservation: RunestoneInputEventReservation {
    private let host: FocusDocumentHost
    init(host: FocusDocumentHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        FocusPublication(host: host, before: host.text, after: candidate.string)
    }
    func close() { host.busy = false }
}

private final class FocusPublication: RunestoneInputPreparedPublication {
    private let host: FocusDocumentHost
    private let before: String
    private let after: String
    init(host: FocusDocumentHost, before: String, after: String) { self.host = host; self.before = before; self.after = after }
    func publish() { host.text = after; host.inputRevision = UUID(); host.publications += 1 }
    func finish() {
        host.undo.beginUndoGrouping()
        let previous = before
        host.undo.registerUndo(withTarget: host) { document in
            document.text = previous
            document.inputRevision = UUID()
            document.bridge.canonicalDocumentDidChange()
            document.bridge.documentGateDidBecomeAvailable()
        }
        host.undo.endUndoGrouping()
        host.undoRegistrations += 1
    }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected publication conflict") }
}

private final class FocusReconstructionReservation: RunestoneInputReconstructionReservation {
    private let host: FocusDocumentHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(host: FocusDocumentHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)])
        revision = host.inputRevision
    }
    func close() { host.busy = false }
}
#endif
