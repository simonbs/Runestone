#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class RunestoneEditableDocumentAttachmentPublicTests: XCTestCase {
    func testPublicSelectionSnapshotCarriesAdditiveCaretIdentity() {
        let affinity = RunestoneEditableDocumentAttachment.CaretAffinity(
            wrapSide: .upstream, bidirectionalSide: nil)
        let snapshot = RunestoneEditableDocumentAttachment.SelectionSnapshot(
            range: NSRange(location: 4, length: 0), text: "",
            activeEndpoint: .caret, caretAffinity: affinity)
        XCTAssertEqual(snapshot.range, NSRange(location: 4, length: 0))
        XCTAssertEqual(snapshot.text, "")
        XCTAssertEqual(snapshot.activeEndpoint, .caret)
        XCTAssertEqual(snapshot.caretAffinity, affinity)
        let compatible = RunestoneEditableDocumentAttachment.SelectionSnapshot(
            range: NSRange(location: 1, length: 2), text: "bc")
        XCTAssertEqual(compatible.activeEndpoint, .upperBound)
        XCTAssertNil(compatible.caretAffinity)
        let bidi = RunestoneEditableDocumentAttachment.CaretAffinity(
            wrapSide: nil, bidirectionalSide: .secondary)
        let bidiSnapshot = RunestoneEditableDocumentAttachment.SelectionSnapshot(
            range: NSRange(location: 7, length: 0), text: "", caretAffinity: bidi)
        XCTAssertEqual(bidiSnapshot.caretAffinity?.bidirectionalSide, .secondary)
    }

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

    func testReadOnlyTransitionKeepsViewAndDocumentConnectionReusable() throws {
        _ = NSApplication.shared
        let host = PublicAttachmentHost("preserved")
        let attachment = try makeAttachment(host: host)
        let view = attachment.view

        XCTAssertFalse(attachment.isReadOnly)
        XCTAssertTrue(attachment.isEditable)
        XCTAssertTrue(attachment.setReadOnly(true))
        XCTAssertTrue(attachment.isReadOnly)
        XCTAssertFalse(attachment.isEditable)
        XCTAssertFalse(attachment.requestFirstResponder())
        XCTAssertTrue(attachment.view === view)
        XCTAssertEqual(view.content.string, "preserved")
        XCTAssertEqual(view.accessibilityRole(), .staticText)

        XCTAssertTrue(attachment.setReadOnly(false))
        XCTAssertFalse(attachment.isReadOnly)
        XCTAssertTrue(attachment.isEditable)
        XCTAssertTrue(attachment.view === view)
        XCTAssertEqual(view.content.string, "preserved")

        XCTAssertFalse(attachment.detach())
        waitForDetach(attachment)
    }

    func testDocumentRangeNavigationValidatesAndWorksWhileReadOnly() throws {
        _ = NSApplication.shared
        let host = PublicAttachmentHost("first\r\nsecond")
        let attachment = try makeAttachment(host: host)

        XCTAssertTrue(attachment.setReadOnly(true))
        XCTAssertTrue(attachment.selectAndRevealDocumentRange(NSRange(location: 7, length: 6)))
        XCTAssertEqual(attachment.presentedSelectionRange, NSRange(location: 7, length: 6))
        XCTAssertFalse(attachment.selectAndRevealDocumentRange(NSRange(location: 99, length: 0)))
        XCTAssertEqual(attachment.presentedSelectionRange, NSRange(location: 7, length: 6))

        XCTAssertFalse(attachment.detach())
        waitForDetach(attachment)
        XCTAssertFalse(attachment.selectAndRevealDocumentRange(NSRange(location: 0, length: 0)))
        XCTAssertNil(attachment.presentedSelectionRange)
    }

    func testFarWrappedReadOnlyRangeNavigationPublishesSelectionAndVisiblePlacement() throws {
        _ = NSApplication.shared
        let text = String(repeating: "alpha beta ", count: 20_000)
        let host = PublicAttachmentHost(text)
        let attachment = try makeAttachment(host: host)
        XCTAssertTrue(attachment.setReadOnly(true))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 340, height: 180))
        let window = NSWindow(contentRect: scroll.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = scroll
        scroll.documentView = attachment.view
        scroll.tile()
        attachment.view.layoutSubtreeIfNeeded()
        waitUntil(timeout: 2) {
            abs(attachment.view.frame.width - scroll.contentView.bounds.width) < 0.01
        }
        let ranges = [NSRange(location: text.utf16.count / 2, length: 1),
                      NSRange(location: text.utf16.count - 2, length: 1)]

        for range in ranges {
            XCTAssertTrue(attachment.selectAndRevealDocumentRange(range))
            waitUntil(timeout: 5) {
                attachment.presentedSelectionRange == range && scroll.contentView.bounds.minY > 0 &&
                    attachment.view.visibleLayout?.lines.contains { line in
                        line.placements.contains { placement in
                            placement.documentRange.location <= range.location &&
                                range.location < placement.documentRange.upperBound
                        }
                    } == true
            }
            XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
            XCTAssertEqual(attachment.presentedSelectionRange, range)
        }

        XCTAssertFalse(attachment.detach())
        waitForDetach(attachment)
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

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(condition())
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
