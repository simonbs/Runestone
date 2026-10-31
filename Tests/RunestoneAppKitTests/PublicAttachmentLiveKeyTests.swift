#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

/// The window is real and becomes key; key events and input-client callbacks
/// are synthetic and do not establish physical keyboard or IME behavior.
final class PublicAttachmentLiveKeyTests: XCTestCase {
    func testPublicAttachmentFocusKeyboardAndReacquisition() throws {
        let fixture = try LivePublicFixture(text: "abc")
        defer { fixture.close() }
        try fixture.activate()
        let oldContext = try XCTUnwrap(fixture.responder.inputContext)
        let oldClient = oldContext.client
        try fixture.sendKey("a", keyCode: 0)
        XCTAssertEqual(fixture.host.text, "aabc")
        XCTAssertEqual(fixture.host.publications, 1)
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 1, length: 0))

        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.other))
        XCTAssertTrue(fixture.window.firstResponder === fixture.other)
        oldClient.insertText("stale", replacementRange: LivePublicFixture.unspecified)
        XCTAssertEqual(fixture.host.text, "aabc")
        try fixture.focus()
        XCTAssertTrue(fixture.window.firstResponder === fixture.responder)
        XCTAssertTrue(fixture.wait(until: {
            guard let current = fixture.responder.inputContext else { return false }
            return current !== oldContext
        }))
        XCTAssertEqual(oldClient.selectedRange().location, NSNotFound)
        try fixture.sendKey("b", keyCode: 11)
        XCTAssertEqual(fixture.host.text, "ababc")
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        withExtendedLifetime(oldContext) {}
    }

    func testSyntheticReturnUsesDocumentLineEnding() throws {
        let fixture = try LivePublicFixture(text: "abc\r\nnext")
        defer { fixture.close() }
        try fixture.activate()
        try fixture.sendKey("\r", keyCode: 36)
        XCTAssertEqual(fixture.host.text, "\r\nabc\r\nnext")
        XCTAssertEqual(fixture.attachment.inputState?.selection, NSRange(location: 2, length: 0))
    }

    func testDirectPublicInputClientAcceptsUnicodeAndEmoji() throws {
        let fixture = try LivePublicFixture(text: "abc")
        defer { fixture.close() }
        try fixture.activate()
        let client = try XCTUnwrap(fixture.responder.inputContext?.client)
        // A direct protocol callback exercises the live input connection; it
        // is not evidence of physical keyboard, Emoji panel, or IME behavior.
        client.insertText("é👩‍💻", replacementRange: LivePublicFixture.unspecified)
        XCTAssertEqual(fixture.host.text, "é👩‍💻abc")
        XCTAssertEqual(fixture.attachment.inputState?.selection,
                       NSRange(location: ("é👩‍💻" as NSString).length, length: 0))
        XCTAssertEqual(fixture.host.publications, 1)
    }

    func testBusyDetachmentDisarmsImmediatelyAndCompletesAfterGateRelease() throws {
        let fixture = try LivePublicFixture(text: "abc")
        defer { fixture.close() }
        try fixture.activate()
        let context = try XCTUnwrap(fixture.responder.inputContext)
        let client = context.client
        fixture.host.externallyBusy = true
        defer { fixture.host.externallyBusy = false }

        XCTAssertFalse(fixture.attachment.detach())
        XCTAssertFalse(fixture.attachment.isEditable)
        XCTAssertFalse(fixture.attachment.requestFirstResponder())
        XCTAssertFalse(fixture.responder.acceptsFirstResponder)
        XCTAssertNil(fixture.attachment.inputState)
        client.insertText("stale", replacementRange: LivePublicFixture.unspecified)
        try fixture.sendKey("a", keyCode: 0)
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.publications, 0)

        // Let the deferred teardown reach the still-held document gate.
        let quiesced = XCTestExpectation(description: "detachment reaches busy gate")
        DispatchQueue.main.async { quiesced.fulfill() }
        XCTAssertEqual(XCTWaiter().wait(for: [quiesced], timeout: 3), .completed)
        XCTAssertFalse(fixture.attachment.detach())
        XCTAssertEqual(fixture.host.text, "abc")

        fixture.host.externallyBusy = false
        fixture.host.bridge.documentGateDidBecomeAvailable()
        let detached = XCTestExpectation(description: "detachment finishes after gate release")
        var attempts = 0
        func attempt() {
            if fixture.attachment.detach() { detached.fulfill(); return }
            attempts += 1
            if attempts >= 100 { XCTFail("Public attachment failed to detach"); detached.fulfill(); return }
            DispatchQueue.main.async(execute: attempt)
        }
        attempt()
        XCTAssertEqual(XCTWaiter().wait(for: [detached], timeout: 3), .completed)
        XCTAssertTrue(fixture.attachment.detach())
        XCTAssertFalse(fixture.attachment.requestFirstResponder())
        client.insertText("later", replacementRange: LivePublicFixture.unspecified)
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.publications, 0)
        withExtendedLifetime(context) {}
    }

    func testBusyDispatchDoesNotApplyOrReplaySyntheticKey() throws {
        let fixture = try LivePublicFixture(text: "abc")
        defer { fixture.close() }
        try fixture.activate()
        fixture.host.externallyBusy = true
        defer { fixture.host.externallyBusy = false }
        try fixture.sendKey("a", keyCode: 0)
        XCTAssertEqual(fixture.host.text, "abc")
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        fixture.host.externallyBusy = false
        fixture.host.bridge.documentGateDidBecomeAvailable()
        let settled = XCTestExpectation(description: "gate availability turn")
        DispatchQueue.main.async { settled.fulfill() }
        XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: 3), .completed)
        XCTAssertEqual(fixture.host.text, "abc")
    }
}

/// Shared by foreground acceptance tests. Uses the public attachment API and a
/// real AppKit context; callers own teardown even when activation is skipped.
final class LivePublicFixture {
    static let unspecified = NSRange(location: NSNotFound, length: 0)
    let host: LivePublicHost
    let attachment: RunestoneEditableDocumentAttachment
    let responder: PreparedInputResponderView
    let window: NSWindow
    let scroll: NSScrollView
    let other: NSView
    private let previousPolicy: NSApplication.ActivationPolicy
    private var closed = false

    init(text: String, font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)) throws {
        let app = NSApplication.shared
        previousPolicy = app.activationPolicy()
        let host = LivePublicHost(text: text, font: font)
        let attachment = try XCTUnwrap(RunestoneEditableDocumentAttachment.attach(
            host: host, lifetime: host.lifetime, bridge: host.bridge))
        let responder = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 360, height: 220),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 220))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 40, width: 360, height: 180))
        let other = LivePublicOtherView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
        container.addSubview(scroll)
        container.addSubview(other)
        scroll.documentView = responder
        window.contentView = container
        scroll.tile()
        responder.updateViewport()
        self.host = host
        self.attachment = attachment
        self.responder = responder
        self.window = window
        self.scroll = scroll
        self.other = other
    }

    func activate() throws {
        let app = NSApplication.shared
        _ = app.setActivationPolicy(.regular)
        app.activate()
        func skipReason(_ stage: String) -> String {
            let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unavailable"
            return "\(stage); active=\(app.isActive), visible=\(window.isVisible), " +
                "key=\(window.isKeyWindow), policy=\(app.activationPolicy()), frontmostBundleID=\(frontmost)"
        }
        guard wait(until: { app.isActive }) else {
            throw XCTSkip(skipReason("The test application did not become active"))
        }
        window.makeKeyAndOrderFront(nil)
        guard wait(until: { self.window.isKeyWindow }) else {
            throw XCTSkip(skipReason("The test process could not obtain a foreground key window"))
        }
        responder.updateViewport()
        guard wait(until: { self.responder.visibleLayout?.isComplete == true &&
            self.responder.visibleLayout?.viewport == self.scroll.contentView.bounds }) else {
            throw LivePublicFixtureError.unavailable("Visible viewport layout did not become current")
        }
        try focus()
    }

    func focus() throws {
        guard wait(until: { self.attachment.isEditable }) else {
            throw LivePublicFixtureError.unavailable("Attachment did not become editable")
        }
        guard attachment.requestFirstResponder() else {
            throw LivePublicFixtureError.unavailable("Public first-responder request was rejected")
        }
        guard wait(until: { self.window.isKeyWindow && self.window.firstResponder === self.responder &&
            self.responder.inputContext != nil && self.attachment.inputState != nil }) else {
            throw LivePublicFixtureError.unavailable("Input context did not become active")
        }
    }

    func sendKey(_ characters: String, keyCode: UInt16,
                 modifiers: NSEvent.ModifierFlags = []) throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: keyCode))
        window.sendEvent(event)
    }

    @discardableResult
    func wait(until condition: @escaping () -> Bool, timeout: TimeInterval = 3) -> Bool {
        if condition() { return true }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func close() {
        guard !closed else { return }
        closed = true
        window.makeFirstResponder(nil)
        let done = XCTestExpectation(description: "public attachment detaches")
        var attempts = 0
        func attempt() {
            if self.attachment.detach() { done.fulfill(); return }
            attempts += 1
            if attempts >= 100 { XCTFail("Attachment failed to detach"); done.fulfill(); return }
            DispatchQueue.main.async(execute: attempt)
        }
        attempt()
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: 3), .completed)
        window.orderOut(nil)
        window.close()
        _ = NSApplication.shared.setActivationPolicy(previousPolicy)
    }
}

enum LivePublicFixtureError: Error { case unavailable(String) }
private final class LivePublicOtherView: NSView { override var acceptsFirstResponder: Bool { true } }

/// A document-owned test gate shared by input, reconstruction and history.
final class LivePublicHost: NSObject, RunestoneInputDispatchHost {
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    let undo = UndoManager()
    let font: NSFont
    var text: String
    var inputRevision = UUID()
    var externallyBusy = false
    var parentOpen = false
    var childOpen = false
    var reconstructionOpen = false
    var historyOpen = false
    var parentStarts = 0
    var parentCloses = 0
    var childStarts = 0
    var childCloses = 0
    var publications = 0
    var completions: [RunestoneInputDispatchCompletion] = []

    init(text: String, font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)) { self.text = text; self.font = font; super.init(); undo.groupsByEvent = false }
    var gateBusy: Bool { externallyBusy || parentOpen || reconstructionOpen || historyOpen }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !gateBusy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        parentOpen = true; parentStarts += 1
        return .reserved(LivePublicParent(self))
    }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !gateBusy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        externallyBusy = true
        return .reserved(LivePublicChild(self, standalone: true))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !gateBusy else { return .busy }
        reconstructionOpen = true
        return .reserved(LivePublicSnapshot(self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] {
        [.font: font]
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        completions.append(completion)
    }
    func canPerformInputHistory(_ operation: RunestoneInputHistoryOperation, expectedRevision: UUID,
                                source: ReadOnlyDocumentView) -> Bool {
        guard !gateBusy, expectedRevision == inputRevision else { return false }
        return operation == .undo ? undo.canUndo : undo.canRedo
    }
    func performInputHistory(_ operation: RunestoneInputHistoryOperation, expectedRevision: UUID,
                             source: ReadOnlyDocumentView) -> RunestoneInputHistoryResult {
        guard !gateBusy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        guard operation == .undo ? undo.canUndo : undo.canRedo else { return .unavailable }
        historyOpen = true
        if operation == .undo { undo.undo() } else { undo.redo() }
        let revision = inputRevision
        historyOpen = false
        bridge.canonicalDocumentDidChange()
        bridge.documentGateDidBecomeAvailable()
        return .success(finalRevision: revision)
    }
    func restore(_ oldText: String) {
        let inverse = text
        undo.registerUndo(withTarget: self) { $0.restore(inverse) }
        text = oldText
        inputRevision = UUID()
    }
}

private final class LivePublicParent: RunestoneInputDispatchReservation {
    let host: LivePublicHost
    init(_ host: LivePublicHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        guard host.parentOpen, !host.childOpen else { return .busy }
        guard expectedRevision == host.inputRevision else { return .stale }
        host.childOpen = true; host.childStarts += 1
        return .reserved(LivePublicChild(host, standalone: false))
    }
    func close() {
        XCTAssertTrue(host.parentOpen); XCTAssertFalse(host.childOpen)
        host.parentOpen = false; host.parentCloses += 1
    }
}

private final class LivePublicChild: RunestoneInputEventReservation {
    let host: LivePublicHost
    let standalone: Bool
    init(_ host: LivePublicHost, standalone: Bool) { self.host = host; self.standalone = standalone }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        LivePublicPublication(host, before: host.text, after: candidate.string)
    }
    func close() {
        if standalone { host.externallyBusy = false }
        else { XCTAssertTrue(host.childOpen); host.childOpen = false; host.childCloses += 1 }
    }
}

private final class LivePublicPublication: RunestoneInputPreparedPublication {
    let host: LivePublicHost
    let before: String
    let after: String
    init(_ host: LivePublicHost, before: String, after: String) { self.host = host; self.before = before; self.after = after }
    func publish() { host.text = after; host.inputRevision = UUID(); host.publications += 1 }
    func finish() {
        host.undo.beginUndoGrouping()
        let before = self.before
        host.undo.registerUndo(withTarget: host) { $0.restore(before) }
        host.undo.endUndoGrouping()
    }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected publication conflict") }
}

private final class LivePublicSnapshot: RunestoneInputReconstructionReservation {
    let host: LivePublicHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: LivePublicHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text,
            attributes: [.font: host.font])
        revision = host.inputRevision
    }
    func close() { host.reconstructionOpen = false }
}
#endif
