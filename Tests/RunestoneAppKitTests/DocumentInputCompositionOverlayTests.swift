#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class DocumentInputCompositionOverlayTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)
    private let documentRevision = UUID()
    private let typing: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14), .underlineStyle: 2]

    func testMarkedUpdatesAreProvisionalAndIdenticalCommitPublishesOnce() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "a", attributes: typing))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var canonical = "a"
        var revision = UUID()
        var preparations = 0
        var finishes = 0
        var accepted: [String] = []
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            preparations += 1
            let text = candidate.string
            XCTAssertEqual(candidate.attribute(.underlineStyle, at: 1, effectiveRange: nil) as? Int, 2)
            return .init(publish: { canonical = text; revision = UUID() }, finish: { finishes += 1 }, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
        session.contentDidChange = { accepted.append($0.string) }
        XCTAssertTrue(session.setSelection(NSRange(location: 1, length: 0)))
        let marked = NSAttributedString(string: "日", attributes: [.underlineStyle: 1])
        XCTAssertTrue(session.setMarkedText(marked, selectedRange: NSRange(location: 1, length: 0), replacementRange: unspecified))
        XCTAssertEqual(canonical, "a")
        XCTAssertEqual(preparations, 0)
        XCTAssertTrue(accepted.isEmpty)
        // The final payload is identical to the provisional characters. It is
        // still an edit relative to the canonical baseline.
        XCTAssertTrue(session.insertText(marked, replacementRange: unspecified))
        XCTAssertEqual(canonical, "a日")
        XCTAssertEqual(preparations, 1)
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(accepted, ["a日"])
        XCTAssertEqual(view.content.attribute(.underlineStyle, at: 1, effectiveRange: nil) as? Int, 2)
        XCTAssertEqual((view.content.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)?.pointSize, 14)
        XCTAssertNil(session.markedRange)
    }

    func testCancellationAndRejectedFinalRestoreBaselineWithoutPublication() throws {
        for reject in [false, true] {
            let baseline = NSAttributedString(string: "abcd", attributes: typing)
            let view = ReadOnlyDocumentView(content: baseline)
            let permit = try XCTUnwrap(view.claimInputMutation())
            var preparations = 0
            var notifications = 0
            let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
                preparations += 1
                return nil
            }, compositionAttributes: { self.typing }, initialDocumentRevision: self.documentRevision, documentRevision: { self.documentRevision })
            session.contentDidChange = { _ in notifications += 1 }
            XCTAssertTrue(session.setSelection(NSRange(location: 1, length: 2)))
            XCTAssertTrue(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                                replacementRange: unspecified, attributes: typing))
            if reject {
                XCTAssertFalse(session.insertText("z", replacementRange: unspecified, attributes: typing))
                XCTAssertEqual(preparations, 1)
            } else {
                XCTAssertTrue(session.cancelComposition())
                XCTAssertEqual(preparations, 0)
            }
            XCTAssertEqual(view.content, baseline)
            XCTAssertEqual(session.selectedRange, NSRange(location: 1, length: 2))
            XCTAssertNil(session.markedRange)
            XCTAssertEqual(notifications, 0)
        }
    }

    func testCompositionReturningToOriginalTextCreatesNoAcceptedChange() throws {
        let baseline = NSAttributedString(string: "abc", attributes: typing)
        let view = ReadOnlyDocumentView(content: baseline)
        let permit = try XCTUnwrap(view.claimInputMutation())
        var prepared = false
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            prepared = true
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: self.documentRevision, documentRevision: { self.documentRevision })
        XCTAssertTrue(session.setSelection(NSRange(location: 1, length: 1)))
        XCTAssertTrue(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertTrue(session.insertText("b", replacementRange: unspecified, attributes: typing))
        XCTAssertEqual(view.content, baseline)
        XCTAssertEqual(session.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertFalse(prepared)
    }

    func testMultipleMarkedUpdatesAndUnmarkCommitOnlyOnce() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "a", attributes: typing))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var canonical = "a"
        var revision = UUID()
        var preparations = 0
        var session: DocumentInputSession!
        session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            preparations += 1
            XCTAssertFalse(session.cancelComposition())
            let result = candidate.string
            return .init(publish: { canonical = result; revision = UUID() }, finish: {}, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
        XCTAssertTrue(session.setSelection(NSRange(location: 1, length: 0)))
        XCTAssertTrue(session.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertTrue(session.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertEqual(canonical, "a")
        XCTAssertTrue(session.unmarkText())
        XCTAssertEqual(canonical, "a日本")
        XCTAssertEqual(preparations, 1)
        XCTAssertNil(session.markedRange)
    }

    func testCompositionUndoIsRegisteredOnlyAtCommit() throws {
        let owner = FakeDocumentOwner(text: "a")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text, attributes: typing))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let previous = owner.text
            let result = candidate.string
            return .init(publish: { owner.text = result; owner.revision = UUID() }, finish: {
                owner.undo.beginUndoGrouping()
                owner.undo.registerUndo(withTarget: owner) { $0.text = previous; $0.revision = UUID() }
                owner.undo.endUndoGrouping()
            }, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: owner.revision, documentRevision: { owner.revision })
        XCTAssertTrue(session.setSelection(NSRange(location: 1, length: 0)))
        XCTAssertTrue(session.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertTrue(session.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertEqual(owner.text, "a")
        XCTAssertEqual(owner.undo.groupingLevel, 0)
        XCTAssertFalse(owner.undo.canUndo)
        XCTAssertTrue(session.cancelComposition())
        XCTAssertFalse(owner.undo.canUndo)
        XCTAssertEqual(owner.undo.groupingLevel, 0)
        XCTAssertTrue(session.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertTrue(session.unmarkText())
        XCTAssertEqual(owner.text, "a日本")
        XCTAssertEqual(owner.undo.groupingLevel, 0)
        XCTAssertTrue(owner.undo.canUndo)
        owner.undo.undo()
        XCTAssertEqual(owner.text, "a")
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: typing))
        XCTAssertTrue(session.hasDocumentConflict)
    }

    func testStaleViewCannotStartCompositionOrOrdinaryEdit() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc", attributes: typing))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var revision = UUID()
        var preparations = 0
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            preparations += 1
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
        revision = UUID() // The canonical document changed before this view synchronized.
        XCTAssertFalse(session.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: unspecified, attributes: typing))
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: typing))
        XCTAssertEqual(preparations, 0)
        XCTAssertEqual(view.content.string, "abc")
        XCTAssertEqual(session.selectedRange, NSRange(location: 0, length: 0))
    }

    func testRevisionChangeInAttributesOrRejectedPrepareDoesNotRestoreStaleBaseline() throws {
        for changeDuringAttributes in [false, true] {
            let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc", attributes: typing))
            let permit = try XCTUnwrap(view.claimInputMutation())
            var revision = UUID()
            let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
                revision = UUID()
                return nil
            }, compositionAttributes: {
                if changeDuringAttributes { revision = UUID() }
                return self.typing
            }, initialDocumentRevision: revision, documentRevision: { revision })
            let marked = session.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0),
                                               replacementRange: unspecified, attributes: typing)
            if changeDuringAttributes {
                XCTAssertFalse(marked)
                XCTAssertEqual(view.content.string, "abc")
            } else {
                XCTAssertTrue(marked)
                XCTAssertFalse(session.insertText("Y", replacementRange: unspecified, attributes: typing))
                XCTAssertEqual(view.content.string, "Xabc")
                XCTAssertEqual(session.markedRange, NSRange(location: 0, length: 1))
            }
            XCTAssertTrue(session.hasDocumentConflict)
            XCTAssertFalse(session.cancelComposition())
        }
    }

    func testChangedCanonicalRevisionPreventsStaleCommitAndCancellation() throws {
        for cancel in [false, true] {
            let view = ReadOnlyDocumentView(content: NSAttributedString(string: "abc", attributes: typing))
            let permit = try XCTUnwrap(view.claimInputMutation())
            var canonical = "abc"
            var revision = UUID()
            var preparations = 0
            let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
                preparations += 1
                let result = candidate.string
                return .init(publish: { canonical = result }, finish: {}, reconcile: { _ in })
            }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
            XCTAssertTrue(session.setSelection(NSRange(location: 1, length: 0)))
            XCTAssertTrue(session.setMarkedText("X", selectedRange: NSRange(location: 1, length: 0),
                                                replacementRange: unspecified, attributes: typing))
            canonical = "abc!" // Another document view committed this revision.
            revision = UUID()
            if cancel { XCTAssertFalse(session.cancelComposition()) }
            else { XCTAssertFalse(session.insertText("X", replacementRange: unspecified, attributes: typing)) }
            XCTAssertEqual(canonical, "abc!")
            XCTAssertEqual(preparations, 0)
            XCTAssertTrue(session.hasDocumentConflict)
            XCTAssertEqual(view.content.string, "aXbc")
            XCTAssertEqual(session.markedRange, NSRange(location: 1, length: 1))
            XCTAssertEqual(session.selectedRange, NSRange(location: 2, length: 0))
            XCTAssertFalse(session.setMarkedText("Y", selectedRange: NSRange(location: 1, length: 0),
                                                 replacementRange: unspecified, attributes: typing))
        }
    }

    func testRevisionChangeDuringProvisionalLayoutBlocksLaterPublication() throws {
        let original = String(repeating: "line\n", count: 100)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original, attributes: typing))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let permit = try XCTUnwrap(view.claimInputMutation())
        var revision = UUID()
        var preparations = 0
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            preparations += 1
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
        view.postsFrameChangedNotifications = true
        var observed = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard !observed else { return }
            observed = true
            revision = UUID()
        }
        XCTAssertFalse(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: NSRange(location: 0, length: original.utf16.count), attributes: typing))
        NotificationCenter.default.removeObserver(observer)
        XCTAssertTrue(observed)
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertFalse(session.cancelComposition())
        XCTAssertFalse(session.insertText("y", replacementRange: unspecified, attributes: typing))
        XCTAssertEqual(preparations, 0)
        XCTAssertEqual(session.markedRange, NSRange(location: 0, length: 1))
    }

    func testRevisionChangeDuringRestorationBlocksLaterEdits() throws {
        for cancel in [false, true] {
            let original = String(repeating: "line\n", count: 100)
            let view = ReadOnlyDocumentView(content: NSAttributedString(string: original, attributes: typing))
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
            scroll.documentView = view
            scroll.tile()
            view.updateViewport()
            let permit = try XCTUnwrap(view.claimInputMutation())
            var revision = UUID()
            var preparations = 0
            let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
                preparations += 1
                return .init(publish: {}, finish: {}, reconcile: { _ in })
            }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
            XCTAssertTrue(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                                replacementRange: NSRange(location: 0, length: original.utf16.count), attributes: typing))
            view.postsFrameChangedNotifications = true
            var observed = false
            let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
                guard !observed else { return }
                observed = true
                revision = UUID()
            }
            if cancel { XCTAssertFalse(session.cancelComposition()) }
            else { XCTAssertFalse(session.insertText(original, replacementRange: unspecified, attributes: typing)) }
            NotificationCenter.default.removeObserver(observer)
            XCTAssertTrue(observed)
            XCTAssertTrue(session.hasDocumentConflict)
            XCTAssertFalse(session.insertText("y", replacementRange: unspecified, attributes: typing))
            XCTAssertEqual(preparations, 0)
        }
    }

    func testReentrantDocumentChangeAfterPublicationLeavesAcceptedEditConflicted() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "a", attributes: typing))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var revision = UUID()
        var canonical = "a"
        var conflicts = 0
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let text = candidate.string
            return .init(publish: { canonical = text; revision = UUID() }, finish: {
                canonical = text + "!"
                revision = UUID() // Invalid owner reentrancy is detected after publication.
            }, reconcile: { phase in
                XCTAssertEqual(phase, .afterFinish)
                conflicts += 1
            })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: revision, documentRevision: { revision })
        XCTAssertTrue(session.insertText("x", replacementRange: unspecified, attributes: typing))
        XCTAssertEqual(canonical, "xa!")
        XCTAssertEqual(conflicts, 1)
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertFalse(session.insertText("y", replacementRange: unspecified, attributes: typing))
    }

    func testMarkedReplacementCannotLeaveOldDecorationsOutsideNewMark() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "", attributes: typing))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            .init(publish: {}, finish: {}, reconcile: { _ in })
        }, compositionAttributes: { self.typing }, initialDocumentRevision: self.documentRevision, documentRevision: { self.documentRevision })
        XCTAssertTrue(session.setMarkedText("abc", selectedRange: NSRange(location: 3, length: 0),
                                            replacementRange: unspecified, attributes: typing))
        XCTAssertFalse(session.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0),
                                             replacementRange: NSRange(location: 1, length: 1), attributes: typing))
        XCTAssertEqual(view.content.string, "abc")
        XCTAssertEqual(session.markedRange, NSRange(location: 0, length: 3))
        XCTAssertTrue(session.cancelComposition())
    }
}

private final class FakeDocumentOwner: NSObject {
    var text: String
    var revision = UUID()
    let undo = UndoManager()
    init(text: String) {
        self.text = text
        super.init()
        undo.groupsByEvent = false
    }
}
#endif
