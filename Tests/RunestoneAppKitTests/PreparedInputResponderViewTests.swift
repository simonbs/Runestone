#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputResponderViewTests: XCTestCase {
    func testNonKeyFirstResponderRemainsInertAndDoesNotExposeContext() throws {
        _ = NSApplication.shared
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        var driver: ResponderTestDriver?
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { client in
                let created = ResponderTestDriver(client)
                driver = created
                return created
            }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 80),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertFalse(window.isKeyWindow)
        XCTAssertNil(view.inputContext)
        XCTAssertEqual(driver?.client?.selectedRange().location, NSNotFound)
        driver?.client?.insertText("bad", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
        window.close()
    }

    func testCommandRoutingReportsBlockedAndUnsupportedWithoutDuplicateForwarding() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        XCTAssertEqual(attachment.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                        replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        var forwarded = 0
        view.routeCommand(NSSelectorFromString("deleteBackward:"), on: connection) { _ in forwarded += 1; return true }
        XCTAssertEqual(forwarded, 0)
        var batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records, [.init(operation: .command,
                                              failure: .init(reason: .compositionActive, effect: .notApplied))])
        XCTAssertEqual(batch.overflowCount, 0)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        view.routeCommand(NSSelectorFromString("transpose:"), on: connection) { _ in forwarded += 1; return true }
        batch = connection.takeInputFailures()
        XCTAssertEqual(forwarded, 0)
        XCTAssertEqual(batch.records, [.init(operation: .command,
                                              failure: .init(reason: .unsupported, effect: .notApplied))])
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testBusySelectionCommandIsReportedOnceAndNeverReplayed() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        host.busy = true
        var forwarded = 0
        view.routeCommand(NSSelectorFromString("moveForward:"), on: connection) { _ in forwarded += 1; return true }
        let batch = connection.takeInputFailures()
        XCTAssertEqual(batch.records, [.init(operation: .command,
                                              failure: .init(reason: .busy, effect: .notApplied))])
        XCTAssertEqual(batch.overflowCount, 0)
        XCTAssertEqual(forwarded, 0)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        queue.runAll()
        host.busy = false
        connection.resumeAfterQuiescing()
        XCTAssertEqual(attachment.adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
        XCTAssertTrue(connection.takeInputFailures().records.isEmpty)
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testOutOfBandKeyBindingCallbacksReportRatherThanDisappear() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        XCTAssertTrue(attachment.connection.resumeForFocus())
        // No window/focus or active interpretKeyEvents stack: the fallback
        // methods cannot safely apply these out-of-band callbacks.
        view.insertTextFromKeyBinding("x")
        view.doCommandFromKeyBinding(NSSelectorFromString("deleteBackward:"))
        XCTAssertEqual(attachment.connection.takeInputFailures().records, [
            .init(operation: .insertText, failure: .init(reason: .unavailable, effect: .notApplied)),
            .init(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))
        ])
        XCTAssertEqual(host.text, "abc")
        XCTAssertEqual(host.undoCount, 0)
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testStaleCommandReportsUnavailableInsteadOfForwarding() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        let attachment = try XCTUnwrap(PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue))
        let view = try XCTUnwrap(attachment.view as? PreparedInputResponderView)
        let connection = attachment.connection
        XCTAssertTrue(connection.resumeForFocus())
        host.text = "newer"
        host.inputRevision = UUID()
        var forwarded = false
        view.routeCommand(NSSelectorFromString("insertTab:"), on: connection) { _ in forwarded = true; return true }
        XCTAssertFalse(forwarded)
        XCTAssertEqual(connection.takeInputFailures().records,
                       [.init(operation: .command, failure: .init(reason: .unavailable, effect: .notApplied))])
        XCTAssertEqual(host.text, "newer")
        XCTAssertEqual(host.undoCount, 0)
        queue.runAll()
        XCTAssertFalse(attachment.disconnect())
        queue.runAll()
        XCTAssertTrue(attachment.disconnect())
    }

    func testAbandonedAttachmentImmediatelyRetiresRetainedResponder() throws {
        let host = ResponderTestHost("abc")
        let queue = ResponderTestQueue()
        var attachment: PreparedInputDocumentAttachment? = PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: host.lifetime, bridge: host.bridge,
            makeDriver: { ResponderTestDriver($0) }, schedule: queue.enqueue)
        let view = try XCTUnwrap(attachment?.view as? PreparedInputResponderView)
        XCTAssertFalse(view.isRetired)
        attachment = nil
        XCTAssertTrue(view.isRetired)
        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertNil(view.inputContext)
        XCTAssertEqual(view.content.string, "")
    }
}

private final class ResponderTestDriver: PreparedInputContextConnection.Driver {
    weak var client: NSTextInputClient?
    private let object = NSObject()
    init(_ client: NSTextInputClient) { self.client = client }
    var associationTarget: NSObject { object }
    var inputContext: NSTextInputContext? { nil }
    func activate() {}
    func handle(_ event: NSEvent) -> Bool { false }
    func invalidateCoordinates() {}
    func discardMarkedText() {}
    func deactivate() {}
}

private final class ResponderTestHost: RunestoneInputDocumentHost {
    var text: String
    var inputRevision = UUID()
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    var busy = false
    var undoCount = 0
    init(_ text: String) { self.text = text }
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart {
        guard !busy else { return .busy }
        guard expectedRevision == inputRevision else { return .stale }
        busy = true
        return .reserved(ResponderEventLease(self))
    }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(ResponderSnapshotLease(self))
    }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
}

private final class ResponderEventLease: RunestoneInputEventReservation {
    let host: ResponderTestHost
    init(_ host: ResponderTestHost) { self.host = host }
    func prepare(candidate: NSAttributedString) -> RunestoneInputPreparedPublication? {
        ResponderPublication(host, text: candidate.string)
    }
    func close() { host.busy = false }
}

private final class ResponderPublication: RunestoneInputPreparedPublication {
    let host: ResponderTestHost
    let text: String
    init(_ host: ResponderTestHost, text: String) { self.host = host; self.text = text }
    func publish() { host.text = text; host.inputRevision = UUID() }
    func finish() { host.undoCount += 1 }
    func reconcile(_ phase: RunestoneInputReconciliationPhase) { XCTFail("Unexpected reconciliation") }
}

private final class ResponderSnapshotLease: RunestoneInputReconstructionReservation {
    let host: ResponderTestHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(_ host: ResponderTestHost) {
        self.host = host
        snapshot = NSAttributedString(string: host.text)
        revision = host.inputRevision
    }
    func close() { host.busy = false }
}

private final class ResponderTestQueue {
    private var pending: [() -> Void] = []
    func enqueue(_ block: @escaping () -> Void) { pending.append(block) }
    func runAll() {
        var limit = 100
        while !pending.isEmpty && limit > 0 {
            limit -= 1
            pending.removeFirst()()
        }
        if !pending.isEmpty { XCTFail("Input queue did not settle") }
    }
}
#endif
