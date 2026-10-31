#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputResponderMovementIntegrationTests: XCTestCase {
    func testSuccessiveVerticalMovesRetainPreferredVisualColumn() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nx\n\nabcdef")
        try fixture.setSelection(NSRange(location: 5, length: 0))
        let starts = fixture.host.parentStarts
        let children = fixture.host.childStarts
        for location in [8, 9, 15] {
            XCTAssertTrue(fixture.send("moveDown:"))
            XCTAssertEqual(fixture.selection, NSRange(location: location, length: 0))
        }
        XCTAssertFalse(fixture.window.isKeyWindow)
        XCTAssertEqual(fixture.host.parentStarts - starts, 3)
        XCTAssertEqual(fixture.host.parentCloses, fixture.host.parentStarts)
        XCTAssertEqual(fixture.host.childStarts - children, 3)
        XCTAssertEqual(fixture.host.childCloses, fixture.host.childStarts)
        XCTAssertEqual(fixture.host.completions.suffix(3).map(\.outcome), [.completed, .completed, .completed])
        XCTAssertEqual(fixture.host.text, "abcdef\nx\n\nabcdef")
        fixture.disconnect()
    }

    func testVerticalSelectionExtensionRetainsFixedAnchorWhenDirectionReverses() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nx\n\nabcdef")
        try fixture.setSelection(NSRange(location: 5, length: 0))
        for (command, expected) in [
            ("moveDownAndModifySelection:", NSRange(location: 5, length: 3)),
            ("moveDownAndModifySelection:", NSRange(location: 5, length: 4)),
            ("moveUpAndModifySelection:", NSRange(location: 5, length: 3)),
            ("moveUpAndModifySelection:", NSRange(location: 5, length: 0))
        ] {
            XCTAssertTrue(fixture.send(command))
            XCTAssertEqual(fixture.selection, expected, command)
        }
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.text, "abcdef\nx\n\nabcdef")
        fixture.disconnect()
    }

    func testLineAndHorizontalCommandsUseCurrentRevisionAndChildGate() throws {
        let fixture = try MovementIntegrationFixture("ab\r\ncd")
        try fixture.setSelection(NSRange(location: 1, length: 0))
        let starts = fixture.host.childStarts
        for (command, expected) in [
            ("moveToBeginningOfLine:", 0),
            ("moveRight:", 1),
            ("moveToEndOfLine:", 2),
            ("moveRight:", 4),
            ("moveLeft:", 2)
        ] {
            XCTAssertTrue(fixture.send(command))
            XCTAssertEqual(fixture.selection, NSRange(location: expected, length: 0), command)
        }
        XCTAssertEqual(fixture.host.childStarts - starts, 5)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(Array(fixture.host.text.utf8), Array("ab\r\ncd".utf8))
        XCTAssertEqual(fixture.host.preparations, 0)
        fixture.disconnect()
    }

    func testDirectStandardSelectorReusesAnActiveDispatchReservation() throws {
        let fixture = try MovementIntegrationFixture("abc")
        XCTAssertTrue(fixture.view.responds(to: NSSelectorFromString("moveForward:")))
        XCTAssertTrue(fixture.view.responds(to: NSSelectorFromString("copy:")))
        let parents = fixture.host.parentStarts
        let children = fixture.host.childStarts
        XCTAssertTrue(fixture.connection.performCoordinatedInput {
            fixture.view.performStandardCommand("moveForward:", on: fixture.connection, hasFocus: { true })
        })
        XCTAssertEqual(fixture.selection, NSRange(location: 1, length: 0))
        XCTAssertEqual(fixture.host.parentStarts - parents, 1)
        XCTAssertEqual(fixture.host.childStarts - children, 1)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .completed)
        fixture.disconnect()
    }

    func testVisualWordMovementAndExtensionRouteThroughTheDocumentGate() throws {
        let fixture = try MovementIntegrationFixture("one, two!")
        try fixture.setSelection(NSRange(location: 0, length: 0))
        let parents = fixture.host.parentStarts
        let children = fixture.host.childStarts
        for (command, expected) in [
            ("moveWordRight:", NSRange(location: 3, length: 0)),
            ("moveWordRight:", NSRange(location: 8, length: 0)),
            ("moveWordLeft:", NSRange(location: 5, length: 0)),
            ("moveWordLeftAndModifySelection:", NSRange(location: 0, length: 5)),
            ("moveWordRightAndModifySelection:", NSRange(location: 3, length: 2)),
            ("moveWordRightAndModifySelection:", NSRange(location: 5, length: 3))
        ] {
            XCTAssertTrue(fixture.send(command))
            XCTAssertEqual(fixture.selection, expected, command)
        }
        XCTAssertEqual(fixture.host.parentStarts - parents, 6)
        XCTAssertEqual(fixture.host.childStarts - children, 6)
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.completions.suffix(6).map(\.outcome),
                       [.completed, .completed, .completed, .completed, .completed, .completed])
        XCTAssertEqual(fixture.host.preparations, 0)
        XCTAssertEqual(fixture.host.text, "one, two!")
        fixture.disconnect()
    }

    func testChangedViewportRejectsMovementInsteadOfUsingOldGeometry() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nx\nabcdef")
        try fixture.setSelection(NSRange(location: 5, length: 0))
        let originalBounds = fixture.scroll.contentView.bounds
        let originalLayout = try XCTUnwrap(fixture.view.visibleLayout)
        XCTAssertEqual(originalBounds, originalLayout.viewport)
        let pasteboard = MovementNoPasteboard()
        func allowed(_ name: String) -> Bool {
            fixture.view.canPerformEditingAction(NSSelectorFromString(name), connection: fixture.connection,
                adapter: fixture.attachment.adapter, pasteboard: pasteboard)
        }
        XCTAssertTrue(allowed("moveDown:"))
        XCTAssertFalse(allowed("transpose:"))
        fixture.scroll.contentView.postsBoundsChangedNotifications = false
        fixture.scroll.contentView.setBoundsSize(NSSize(width: originalBounds.width - 30, height: originalBounds.height))
        XCTAssertNotEqual(fixture.scroll.contentView.bounds, originalLayout.viewport)
        XCTAssertFalse(allowed("moveDown:"))
        let children = fixture.host.childStarts
        XCTAssertTrue(fixture.send("moveDown:"))
        XCTAssertEqual(fixture.selection, NSRange(location: 5, length: 0))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.connection.takeInputFailures().records,
                       [.init(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))])
        XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied)
        fixture.scroll.contentView.setBoundsSize(originalBounds.size)
        fixture.scroll.contentView.postsBoundsChangedNotifications = true
        fixture.view.updateViewport()
        fixture.disconnect()
    }

    func testStaleRevisionRejectsMovementBeforeAnOldSelectionCanBeApplied() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        try fixture.setSelection(NSRange(location: 3, length: 0))
        let children = fixture.host.childStarts
        fixture.host.inputRevision = UUID()
        XCTAssertFalse(fixture.send("moveDown:"))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.stale))
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        XCTAssertEqual(fixture.attachment.adapter.selectedRangeForInput().location, NSNotFound)
        fixture.queue.runAll()
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        fixture.disconnect()
    }

    func testPointerDragCrossesItsFixedAnchorAndClampsOutsideViewport() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        XCTAssertTrue(try fixture.beginPointer(at: 3))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 0))
        XCTAssertTrue(try fixture.continuePointer(at: 5))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 2))
        XCTAssertTrue(try fixture.continuePointer(at: 1))
        XCTAssertEqual(fixture.selection, NSRange(location: 1, length: 2))

        let inside = try fixture.screenPoint(at: 5)
        let viewport = try XCTUnwrap(fixture.view.visibleLayout?.viewport)
        let screenViewport = fixture.window.convertToScreen(fixture.view.convert(viewport, to: nil))
        XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.maxX + 1000, y: inside.y)))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 3))
        XCTAssertTrue(fixture.continuePointer(atScreen: NSPoint(x: screenViewport.minX - 1000, y: inside.y)))
        XCTAssertEqual(fixture.selection, NSRange(location: 0, length: 3))
        XCTAssertEqual(fixture.host.parentStarts, fixture.host.parentCloses)
        XCTAssertEqual(fixture.host.childStarts, fixture.host.childCloses)
        XCTAssertEqual(fixture.host.preparations, 0)
        XCTAssertEqual(fixture.host.text, "abcdef\nxyz")
        fixture.disconnect()
    }

    func testPointerGateRejectionAndFocusLossDoNotReplayGesture() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        XCTAssertTrue(try fixture.beginPointer(at: 2))
        let target = try fixture.screenPoint(at: 5)
        let children = fixture.host.childStarts
        fixture.host.externallyBusy = true
        XCTAssertFalse(fixture.continuePointer(atScreen: target))
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        XCTAssertEqual(fixture.host.childStarts, children)
        fixture.host.externallyBusy = false
        fixture.queue.runAll()
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))

        XCTAssertTrue(fixture.continuePointer(atScreen: target, hasFocus: false))
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))
        XCTAssertTrue(fixture.continuePointer(atScreen: target)) // A new callback cannot revive the lost gesture.
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))
        XCTAssertEqual(fixture.connection.takeInputFailures().records.map(\.failure.reason), [.unavailable, .unavailable])
        XCTAssertEqual(fixture.host.childStarts, children)
        fixture.view.disarmForDetachment()
        XCTAssertTrue(fixture.continuePointer(atScreen: target))
        XCTAssertEqual(fixture.selection, NSRange(location: 2, length: 0))
        fixture.disconnect()
    }

    func testPointerDragRejectsStaleDocumentRevisionWithoutReplay() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        XCTAssertTrue(try fixture.beginPointer(at: 2))
        let target = try fixture.screenPoint(at: 5)
        let children = fixture.host.childStarts
        fixture.host.inputRevision = UUID()
        XCTAssertFalse(fixture.continuePointer(atScreen: target))
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.stale))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        fixture.queue.runAll()
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.view.content.string, "abcdef\nxyz")
        fixture.disconnect()
    }

    func testFocusLossDuringChildAdmissionCannotApplyEditingCommands() throws {
        for command in ["moveForward:", "moveRight:", "deleteBackward:", "insertNewline:"] {
            let fixture = try MovementIntegrationFixture("abc\r\ndef")
            try fixture.setSelection(NSRange(location: 1, length: 0))
            fixture.host.onBeginChild = { fixture.connection.suspendForFocusLoss() }
            XCTAssertTrue(fixture.send(command), command)
            fixture.host.onBeginChild = nil
            XCTAssertEqual(fixture.host.text, "abc\r\ndef", command)
            XCTAssertEqual(fixture.host.preparations, 0, command)
            XCTAssertEqual(fixture.host.completions.last?.outcome, .mayHaveApplied, command)
            fixture.queue.runAll()
            XCTAssertEqual(fixture.view.content.string, "abc\r\ndef", command)
            fixture.disconnect()
        }
    }

    func testParentGateContentionDoesNotMoveOrReplaySelection() throws {
        let fixture = try MovementIntegrationFixture("abcdef\nxyz")
        try fixture.setSelection(NSRange(location: 3, length: 0))
        fixture.host.externallyBusy = true
        let children = fixture.host.childStarts
        XCTAssertFalse(fixture.send("moveDown:"))
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 0))
        XCTAssertEqual(fixture.host.childStarts, children)
        XCTAssertEqual(fixture.host.completions.last?.outcome, .rejectedBeforeAdmission(.busy))
        fixture.host.externallyBusy = false
        fixture.queue.runAll()
        XCTAssertEqual(fixture.selection, NSRange(location: 3, length: 0))
        fixture.disconnect()
    }
}

private struct MovementNoPasteboard: PreparedInputClipboardCommand.Pasteboard {
    var hasPlainText: Bool { false }
    func readPlainText() -> String? { nil }
    func writePlainText(_ value: String) -> Bool { false }
}

private final class MovementIntegrationFixture {
    let host: MovementIntegrationHost
    let queue: MovementIntegrationQueue
    let attachment: PreparedInputDocumentAttachment
    let view: PreparedInputResponderView
    let connection: PreparedInputContextConnection
    let window: NSWindow
    let scroll: NSScrollView

    init(_ text: String) throws {
        _ = NSApplication.shared
        let host = MovementIntegrationHost(text)
        let queue = MovementIntegrationQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { MovementIntegrationDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 240, height: 130),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: try XCTUnwrap(window.contentView).bounds)
        window.contentView?.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        self.host = host
        self.queue = queue
        self.attachment = attachment
        self.view = view
        self.connection = attachment.connection
        self.window = window
        self.scroll = scroll
        XCTAssertFalse(window.isKeyWindow)
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertNotNil(view.visibleLayout)
    }

    var selection: NSRange { attachment.adapter.selectedRangeForInput() }

    func setSelection(_ range: NSRange) throws {
        var result: PreparedInputEventAdapter.Outcome?
        XCTAssertTrue(connection.performCoordinatedInput { result = self.attachment.adapter.setSelection(range) })
        XCTAssertEqual(try XCTUnwrap(result), .processed)
    }

    @discardableResult
    func send(_ name: String) -> Bool {
        var forwarded = false
        let admitted = connection.performCoordinatedInput {
            self.view.routeCommand(NSSelectorFromString(name), on: self.connection) { _ in
                forwarded = true
                return true
            }
        }
        XCTAssertFalse(forwarded, "\(name) must remain in the document input contract")
        return admitted
    }

    func screenPoint(at offset: Int) throws -> NSPoint {
        let rect = try XCTUnwrap(InputScreenCaretGeometry.rect(at: offset, in: view))
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    func beginPointer(at offset: Int) throws -> Bool {
        let point = try screenPoint(at: offset)
        return connection.performCoordinatedInput {
            self.view.beginPointerSelection(at: point, extending: false, connection: self.connection, hasFocus: { true })
        }
    }

    func continuePointer(at offset: Int) throws -> Bool {
        continuePointer(atScreen: try screenPoint(at: offset))
    }

    func continuePointer(atScreen point: NSPoint, hasFocus: Bool = true) -> Bool {
        connection.performCoordinatedInput {
            self.view.continuePointerSelection(at: point, connection: self.connection, hasFocus: { hasFocus })
        }
    }

    func disconnect() {
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
        window.close()
    }
}

private final class MovementIntegrationHost: RunestoneInputDispatchHost {
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    let text: String
    var inputRevision = UUID()
    var externallyBusy = false
    var reconstructionOpen = false
    var parentOpen = false
    var childOpen = false
    var parentStarts = 0
    var parentCloses = 0
    var childStarts = 0
    var childCloses = 0
    var preparations = 0
    var completions: [RunestoneInputDispatchCompletion] = []
    var onBeginChild: (() -> Void)?

    init(_ text: String) { self.text = text }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        XCTFail("Selection must reserve a child through the active parent")
        return .busy
    }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart {
        guard !externallyBusy, !reconstructionOpen, !parentOpen else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        parentOpen = true
        parentStarts += 1
        return .reserved(MovementIntegrationParent(self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !externallyBusy, !reconstructionOpen, !parentOpen else { return .busy }
        reconstructionOpen = true
        return .reserved(MovementIntegrationSnapshot(self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]
    }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {
        XCTAssertFalse(parentOpen)
        XCTAssertFalse(childOpen)
        completions.append(completion)
    }
}

private final class MovementIntegrationParent: RunestoneInputDispatchReservation {
    let host: MovementIntegrationHost
    init(_ host: MovementIntegrationHost) { self.host = host }
    func beginInputOperation(expectedRevision: UUID) -> RunestoneInputEventStart {
        guard host.parentOpen, !host.childOpen else { return .busy }
        guard expectedRevision == host.inputRevision else { return .stale }
        host.childOpen = true
        host.childStarts += 1
        host.onBeginChild?()
        return .reserved(MovementIntegrationChild(host))
    }
    func close() {
        XCTAssertTrue(host.parentOpen)
        XCTAssertFalse(host.childOpen)
        host.parentOpen = false
        host.parentCloses += 1
    }
}

private final class MovementIntegrationChild: RunestoneInputEventReservation {
    let host: MovementIntegrationHost
    init(_ host: MovementIntegrationHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        host.preparations += 1
        XCTFail("Selection movement must not prepare a document change")
        return nil
    }
    func close() {
        XCTAssertTrue(host.childOpen)
        host.childOpen = false
        host.childCloses += 1
    }
}

private final class MovementIntegrationSnapshot: RunestoneInputReconstructionReservation {
    let host: MovementIntegrationHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: MovementIntegrationHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)])
        revision = host.inputRevision
    }
    func close() { host.reconstructionOpen = false }
}

private final class MovementIntegrationDriver: PreparedInputContextConnection.Driver {
    let object = NSObject()
    init(_ client: NSTextInputClient) {}
    var associationTarget: NSObject { object }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class MovementIntegrationQueue {
    private var work: [() -> Void] = []
    func enqueue(_ body: @escaping () -> Void) { work.append(body) }
    func runAll() {
        var count = 0
        while !work.isEmpty && count < 200 {
            count += 1
            work.removeFirst()()
        }
        XCTAssertTrue(work.isEmpty, "The input queue must not poll indefinitely")
    }
}
#endif
