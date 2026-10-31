#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class DocumentInputAcceptedChangeTests: XCTestCase {
    private let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testRejectedChangeLeavesViewCanonicalStateAndSelectionUntouched() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "original", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var canonical = "original"
        var notifications = 0
        var session: DocumentInputSession!
        session = DocumentInputSession(view: view, mutationPermit: permit) { candidate in
            XCTAssertFalse(session.insertText("nested", replacementRange: self.unspecified, attributes: self.attributes))
            guard !candidate.string.contains("\0") else { return nil }
            let accepted = candidate.string
            return .init(publish: { canonical = accepted }, finish: { notifications += 1 })
        }
        XCTAssertTrue(session.setSelection(NSRange(location: 8, length: 0)))
        XCTAssertFalse(session.insertText("\0", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "original")
        XCTAssertEqual(canonical, "original")
        XCTAssertEqual(session.selectedRange, NSRange(location: 8, length: 0))
        XCTAssertFalse(session.refresh(content: NSAttributedString(string: "foreign")))
        XCTAssertEqual(view.content.string, canonical)
        XCTAssertEqual(session.selectedRange, NSRange(location: 8, length: 0))
        XCTAssertEqual(notifications, 0)
        XCTAssertFalse(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified, attributes: attributes))
        XCTAssertNil(session.markedRange)
    }

    func testCanonicalPublicationPrecedesLayoutAndFinishRejectsReentrancy() throws {
        let original = String(repeating: "line\n", count: 100)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original, attributes: attributes))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.layoutSubtreeIfNeeded()
        let permit = try XCTUnwrap(view.claimInputMutation())
        var canonical = original
        var observed = false
        var finished = false
        var session: DocumentInputSession!
        session = DocumentInputSession(view: view, mutationPermit: permit) { candidate in
            let accepted = candidate.string
            return .init(publish: { canonical = accepted }, finish: {
                XCTAssertTrue(observed)
                XCTAssertEqual(canonical, "short")
                XCTAssertFalse(session.insertText("nested", replacementRange: self.unspecified, attributes: self.attributes))
                XCTAssertFalse(view.releaseInputMutation(permit))
                finished = true
            })
        }
        view.postsFrameChangedNotifications = true
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                               object: view, queue: nil) { _ in
            guard !observed else { return }
            observed = true
            XCTAssertEqual(canonical, "short")
            XCTAssertEqual(view.content.string, canonical)
            XCTAssertEqual(session.selectedRange, NSRange(location: 5, length: 0))
            XCTAssertNil(view.setContentReturningRevision(NSAttributedString(string: "foreign"), permit: permit))
            XCTAssertNil(view.replaceContentReturningRevision(in: NSRange(location: 0, length: 5),
                                                              with: NSAttributedString(string: "foreign"), permit: permit))
            XCTAssertEqual(view.content.string, canonical)
            XCTAssertFalse(session.isStale)
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        XCTAssertTrue(session.insertText("short", replacementRange: NSRange(location: 0, length: original.utf16.count),
                                         attributes: attributes))
        XCTAssertTrue(observed)
        XCTAssertTrue(finished)
        XCTAssertEqual(canonical, "short")
    }

    func testPreparedChangesRequireExclusiveOwnership() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "original", attributes: attributes))
        var prepared = false
        let session = DocumentInputSession(view: view, prepareChange: { _ in
            prepared = true
            return .init(publish: {}, finish: {})
        })
        XCTAssertTrue(session.isStale)
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertFalse(prepared)
        XCTAssertEqual(view.content.string, "original")
    }

    func testIdenticalReplacementDoesNotPrepareOrPublish() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "x", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var prepared = false
        let session = DocumentInputSession(view: view, mutationPermit: permit) { _ in
            prepared = true
            return .init(publish: {}, finish: {})
        }
        XCTAssertTrue(session.insertText("x", replacementRange: NSRange(location: 0, length: 1), attributes: attributes))
        XCTAssertFalse(prepared)
        XCTAssertEqual(session.selectedRange, NSRange(location: 1, length: 0))
    }
}
#endif
