#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class DocumentInputSessionTests: XCTestCase {
    private var attributes: [NSAttributedString.Key: Any] { [.font: NSFont.systemFont(ofSize: 14)] }
    private var unspecified: NSRange { NSRange(location: NSNotFound, length: 0) }

    func testInsertionUsesSelectionAndNotifiesWithUpdatedStateAndCopiedContent() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "😀tail", attributes: attributes))
        let session = DocumentInputSession(view: view)
        XCTAssertTrue(session.setSelection(NSRange(location: 2, length: 4)))
        var notifications: [NSAttributedString] = []
        session.contentDidChange = { content in
            notifications.append(content)
            XCTAssertEqual(session.selectedRange, NSRange(location: 3, length: 0))
            XCTAssertNil(session.markedRange)
        }
        XCTAssertTrue(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "😀x")
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.string, "😀x")
        XCTAssertEqual((notifications.first?.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize, 14)
        session.contentDidChange = nil
        XCTAssertTrue(session.insertText("!", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(notifications.first?.string, "😀x")
    }

    func testCompositionReplacesMarkedRangeAndUsesRelativeUTF16Selection() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "start", attributes: attributes))
        let session = DocumentInputSession(view: view)
        XCTAssertTrue(session.setSelection(NSRange(location: 5, length: 0)))
        var changes: [String] = []
        session.contentDidChange = { changes.append($0.string) }
        XCTAssertTrue(session.setMarkedText("🐢a", selectedRange: NSRange(location: 2, length: 1),
                                            replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(session.markedRange, NSRange(location: 5, length: 3))
        XCTAssertEqual(session.selectedRange, NSRange(location: 7, length: 1))
        XCTAssertTrue(session.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0),
                                            replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "start日本")
        XCTAssertEqual(session.markedRange, NSRange(location: 5, length: 2))
        XCTAssertEqual(session.selectedRange, NSRange(location: 7, length: 0))
        XCTAssertTrue(session.insertText("日本", replacementRange: unspecified, attributes: attributes))
        XCTAssertNil(session.markedRange)
        XCTAssertEqual(session.selectedRange, NSRange(location: 7, length: 0))
        XCTAssertEqual(changes, ["start🐢a", "start日本"])
        XCTAssertTrue(session.unmarkText())
        XCTAssertEqual(changes.count, 2)
    }

    func testRejectedOperationsLeaveContentSelectionAndMarkedStateUnchanged() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "😀", attributes: attributes))
        let session = DocumentInputSession(view: view)
        var changes = 0
        session.contentDidChange = { _ in changes += 1 }
        XCTAssertFalse(session.setSelection(NSRange(location: 1, length: 0)))
        XCTAssertFalse(session.setSelection(NSRange(location: 0, length: Int.max)))
        XCTAssertFalse(session.insertText("x", replacementRange: NSRange(location: 0, length: 1), attributes: attributes))
        XCTAssertFalse(session.setMarkedText("🐢", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "😀")
        XCTAssertEqual(session.selectedRange, NSRange(location: 0, length: 0))
        XCTAssertNil(session.markedRange)
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(session.setMarkedText("ok", selectedRange: NSRange(location: 2, length: 0),
                                            replacementRange: unspecified, attributes: attributes))
        XCTAssertFalse(session.setMarkedText("new", selectedRange: NSRange(location: 4, length: 0),
                                             replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "ok😀")
        XCTAssertEqual(session.markedRange, NSRange(location: 0, length: 2))
        XCTAssertEqual(session.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertEqual(changes, 1)
    }

    func testAttributeOnlyReplacementNotifiesAndIdenticalReplacementDoesNot() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "x", attributes: attributes))
        let session = DocumentInputSession(view: view)
        var changes = 0
        session.contentDidChange = { _ in changes += 1 }
        let range = NSRange(location: 0, length: 1)
        XCTAssertTrue(session.insertText("x", replacementRange: range, attributes: attributes))
        XCTAssertEqual(changes, 0)
        let large: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24)]
        XCTAssertTrue(session.insertText("x", replacementRange: range, attributes: large))
        XCTAssertEqual(changes, 1)
        XCTAssertEqual((view.content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 24)
    }

    func testExternalRefreshInvalidatesSessionUntilSilentRefresh() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "original", attributes: attributes))
        let session = DocumentInputSession(view: view)
        var changes = 0
        session.contentDidChange = { _ in changes += 1 }
        XCTAssertTrue(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                            replacementRange: unspecified, attributes: attributes))
        let sameContent = view.content
        view.setContent(sameContent)
        XCTAssertTrue(session.isStale)
        XCTAssertEqual(session.selectedRange.location, NSNotFound)
        XCTAssertNil(session.markedRange)
        XCTAssertTrue(session.refresh(content: sameContent))
        XCTAssertEqual(changes, 1)
        view.setContent(NSAttributedString(string: "new", attributes: attributes))
        XCTAssertTrue(session.isStale)
        XCTAssertEqual(session.selectedRange.location, NSNotFound)
        XCTAssertNil(session.markedRange)
        XCTAssertFalse(session.setSelection(NSRange(location: 0, length: 0)))
        XCTAssertFalse(session.insertText("bad", replacementRange: unspecified, attributes: attributes))
        XCTAssertFalse(session.unmarkText())
        XCTAssertEqual(view.content.string, "new")
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(session.refresh(content: view.content))
        XCTAssertFalse(session.isStale)
        XCTAssertNil(session.markedRange)
        XCTAssertEqual(session.selectedRange, NSRange(location: 0, length: 0))
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(session.insertText("ok", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "oknew")
        XCTAssertEqual(changes, 2)
    }

    func testDirectViewMutationDuringCallbackMakesSessionStale() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "", attributes: attributes))
        let session = DocumentInputSession(view: view)
        session.contentDidChange = { _ in view.setContent(view.content) }
        XCTAssertTrue(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertTrue(session.isStale)
        XCTAssertFalse(session.insertText("y", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "x")
    }

    func testSessionStateMatchesContentDuringSynchronousLayoutNotifications() {
        for refreshing in [false, true] {
            let original = NSAttributedString(string: String(repeating: "line\n", count: 100), attributes: attributes)
            let view = ReadOnlyDocumentView(content: original)
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
            scroll.documentView = view
            scroll.tile()
            view.layoutSubtreeIfNeeded()
            let session = DocumentInputSession(view: view)
            XCTAssertTrue(session.setSelection(NSRange(location: original.length, length: 0)))
            XCTAssertTrue(session.setMarkedText("old", selectedRange: NSRange(location: 3, length: 0),
                                                replacementRange: unspecified, attributes: attributes))
            var events: [String] = []
            session.contentDidChange = { _ in events.append("change") }
            var observed = false
            view.postsFrameChangedNotifications = true
            let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                                   object: view, queue: nil) { _ in
                guard !observed else { return }
                observed = true
                events.append("layout")
                XCTAssertEqual(view.content.string, "short")
                XCTAssertEqual(view.manager.stringView.string as String, "short")
                XCTAssertFalse(session.isStale)
                XCTAssertEqual(session.selectedRange, refreshing ? NSRange(location: 0, length: 0) : NSRange(location: 2, length: 1))
                XCTAssertEqual(session.markedRange, refreshing ? nil : NSRange(location: 0, length: 5))
                XCTAssertFalse(session.insertText("nested", replacementRange: self.unspecified, attributes: self.attributes))
            }
            let accepted: Bool
            if refreshing {
                accepted = session.refresh(content: NSAttributedString(string: "short", attributes: attributes))
            } else {
                accepted = session.setMarkedText("short", selectedRange: NSRange(location: 2, length: 1),
                                                 replacementRange: NSRange(location: 0, length: view.content.length),
                                                 attributes: attributes)
            }
            NotificationCenter.default.removeObserver(observer)
            XCTAssertTrue(accepted)
            XCTAssertTrue(observed)
            XCTAssertEqual(events, refreshing ? ["layout"] : ["layout", "change"])
        }
    }

    func testExternalReplacementDuringLayoutLeavesSessionStale() {
        for refreshing in [false, true] {
            let original = NSAttributedString(string: String(repeating: "line\n", count: 100), attributes: attributes)
            let view = ReadOnlyDocumentView(content: original)
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
            scroll.documentView = view
            scroll.tile()
            view.layoutSubtreeIfNeeded()
            let session = DocumentInputSession(view: view)
            var notifications = 0
            session.contentDidChange = { _ in notifications += 1 }
            var replaced = false
            view.postsFrameChangedNotifications = true
            let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                                   object: view, queue: nil) { _ in
                guard !replaced else { return }
                replaced = true
                XCTAssertFalse(session.isStale)
                XCTAssertEqual(view.content.string, "short")
                XCTAssertEqual(session.selectedRange, refreshing ? NSRange(location: 0, length: 0) : NSRange(location: 5, length: 0))
                view.setContent(NSAttributedString(string: "foreign"))
            }
            let accepted: Bool
            if refreshing {
                accepted = session.refresh(content: NSAttributedString(string: "short", attributes: attributes))
            } else {
                accepted = session.insertText("short", replacementRange: NSRange(location: 0, length: original.length),
                                               attributes: attributes)
            }
            NotificationCenter.default.removeObserver(observer)
            XCTAssertFalse(accepted)
            XCTAssertTrue(replaced)
            XCTAssertTrue(session.isStale)
            XCTAssertEqual(view.content.string, "foreign")
            XCTAssertEqual(notifications, 0)
            view.layoutSubtreeIfNeeded()
            XCTAssertEqual(view.manager.stringView.string as String, "foreign")
            XCTAssertNotNil(view.visibleLayout)
        }
    }

    func testCallbackRejectsReentrantSessionMutations() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "", attributes: attributes))
        let session = DocumentInputSession(view: view)
        var changes = 0
        session.contentDidChange = { _ in
            changes += 1
            XCTAssertEqual(session.markedRange, NSRange(location: 0, length: 1))
            XCTAssertEqual(session.selectedRange, NSRange(location: 1, length: 0))
            XCTAssertFalse(session.setSelection(NSRange(location: 0, length: 0)))
            XCTAssertFalse(session.insertText("nested", replacementRange: self.unspecified, attributes: self.attributes))
            XCTAssertFalse(session.setMarkedText("nested", selectedRange: NSRange(location: 0, length: 0),
                                                  replacementRange: self.unspecified, attributes: self.attributes))
            XCTAssertFalse(session.unmarkText())
            XCTAssertFalse(session.refresh(content: NSAttributedString(string: "other")))
        }
        XCTAssertTrue(session.setMarkedText("a", selectedRange: NSRange(location: 1, length: 0),
                                            replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "a")
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(session.unmarkText())
        XCTAssertNil(session.markedRange)
    }
}
#endif
