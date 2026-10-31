#if canImport(AppKit)
import AppKit
import RunestoneAppKit
import XCTest

final class RunestoneEditableDocumentAttachmentPublicTests: XCTestCase {
    func testPublicAttachmentCreatesUnfocusedViewAndDetaches() throws {
        _ = NSApplication.shared
        let host = PublicAttachmentHost("first\r\nsecond")
        let attachment = try XCTUnwrap(RunestoneEditableDocumentAttachment.attach(host: host, lifetime: host.lifetime,
                                                                                   bridge: host.bridge))
        XCTAssertTrue(attachment.isEditable)
        XCTAssertEqual(attachment.view.content.string, "first\r\nsecond")
        XCTAssertNil(attachment.view.window)
        XCTAssertFalse(attachment.view.acceptsFirstResponder)
        XCTAssertFalse(attachment.requestFirstResponder())
        XCTAssertFalse(attachment.view.acceptsFirstResponder)
        XCTAssertFalse(attachment.detach())
        XCTAssertFalse(attachment.isEditable)
        XCTAssertFalse(attachment.view.acceptsFirstResponder)
        XCTAssertNil(attachment.inputState)
        XCTAssertNil(attachment.selectionSnapshot)
        XCTAssertFalse(attachment.requestFirstResponder())
        waitForDetach(attachment)
        XCTAssertTrue(attachment.detach())
        XCTAssertFalse(attachment.isEditable)
    }

    func testMultipleViewsShareOneDocumentWithoutSharingAttachmentLifetime() throws {
        _ = NSApplication.shared
        let host = PublicAttachmentHost("shared")
        let first = try makeAttachment(host: host)
        let second = try makeAttachment(host: host)
        XCTAssertFalse(first.view === second.view)
        XCTAssertTrue(first.isEditable)
        XCTAssertTrue(second.isEditable)
        XCTAssertFalse(first.detach())
        waitForDetach(first)
        XCTAssertFalse(first.isEditable)
        XCTAssertTrue(second.isEditable)
        XCTAssertEqual(second.view.content.string, "shared")
        XCTAssertFalse(second.detach())
        waitForDetach(second)
    }

    func testBridgeRejectsDifferentDocumentHost() throws {
        _ = NSApplication.shared
        let firstHost = PublicAttachmentHost("first")
        let secondHost = PublicAttachmentHost("second")
        let attachment = try makeAttachment(host: firstHost)
        XCTAssertNil(RunestoneEditableDocumentAttachment.attach(host: secondHost, lifetime: secondHost.lifetime,
                                                                 bridge: firstHost.bridge))
        XCTAssertFalse(attachment.detach())
        waitForDetach(attachment)
    }

    func testBusyOrInvalidatedDocumentCannotAttach() {
        let host = PublicAttachmentHost("text")
        host.busy = true
        XCTAssertNil(RunestoneEditableDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge))
        host.busy = false
        host.lifetime.invalidate()
        XCTAssertNil(RunestoneEditableDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge))
    }

    func testViewBecomesInertWhenHostLifetimeEnds() throws {
        _ = NSApplication.shared
        var host: PublicAttachmentHost? = PublicAttachmentHost("private")
        let hostIsAlive = { [weak host] in host != nil }
        let attachment = try makeAttachment(host: try XCTUnwrap(host))
        host = nil
        XCTAssertFalse(hostIsAlive())
        XCTAssertFalse(attachment.isEditable)
        XCTAssertFalse(attachment.requestFirstResponder())
        XCTAssertNil(attachment.inputState)
        XCTAssertNil(attachment.selectionSnapshot)
        XCTAssertTrue(attachment.view.isHidden)
        XCTAssertEqual(attachment.view.content.string, "")
    }

    private func makeAttachment(host: PublicAttachmentHost) throws -> RunestoneEditableDocumentAttachment {
        try XCTUnwrap(RunestoneEditableDocumentAttachment.attach(host: host, lifetime: host.lifetime, bridge: host.bridge))
    }

    private func waitForDetach(_ attachment: RunestoneEditableDocumentAttachment) {
        let done = expectation(description: "input context is detached")
        var retries = 0
        func attempt() {
            if attachment.detach() { done.fulfill(); return }
            retries += 1
            if retries == 100 { XCTFail("Attachment failed to detach"); done.fulfill(); return }
            DispatchQueue.main.async(execute: attempt)
        }
        DispatchQueue.main.async(execute: attempt)
        wait(for: [done], timeout: 3)
    }
}

private final class PublicAttachmentHost: RunestoneInputDispatchHost {
    let lifetime = RunestoneInputDocumentLifetime()
    let bridge = RunestoneInputDocumentBridge()
    let inputRevision = UUID()
    let text: String
    var busy = false

    init(_ text: String) { self.text = text }
    func beginInputDispatch(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputDispatchStart { .busy }
    func inputDispatchDidComplete(_ completion: RunestoneInputDispatchCompletion, source: ReadOnlyDocumentView) {}
    func beginInputEvent(expectedRevision: UUID, source: ReadOnlyDocumentView) -> RunestoneInputEventStart { .busy }
    func typingAttributes(for source: ReadOnlyDocumentView) -> [NSAttributedString.Key: Any] { [:] }
    func beginInputReconstruction() -> RunestoneInputReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(PublicAttachmentSnapshot(host: self))
    }
}

private final class PublicAttachmentSnapshot: RunestoneInputReconstructionReservation {
    let host: PublicAttachmentHost
    let snapshot: NSAttributedString
    let revision: UUID
    init(host: PublicAttachmentHost) {
        self.host = host
        self.snapshot = NSAttributedString(string: host.text)
        self.revision = host.inputRevision
    }
    func close() { host.busy = false }
}
#endif
