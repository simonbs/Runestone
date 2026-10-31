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
        var revision = UUID()
        var notifications = 0
        var session: DocumentInputSession!
        session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            XCTAssertFalse(session.insertText("nested", replacementRange: self.unspecified, attributes: self.attributes))
            guard !candidate.string.contains("\0") else { return nil }
            let accepted = candidate.string
            return .init(publish: { canonical = accepted; revision = UUID() }, finish: { notifications += 1 }, reconcile: { _ in })
        }, initialDocumentRevision: revision, documentRevision: { revision })
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
        var revision = UUID()
        var observed = false
        var finished = false
        var session: DocumentInputSession!
        session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let accepted = candidate.string
            return .init(publish: { canonical = accepted; revision = UUID() }, finish: {
                XCTAssertTrue(observed)
                XCTAssertEqual(canonical, "short")
                XCTAssertFalse(session.insertText("nested", replacementRange: self.unspecified, attributes: self.attributes))
                XCTAssertFalse(view.releaseInputMutation(permit))
                finished = true
            }, reconcile: { _ in })
        }, initialDocumentRevision: revision, documentRevision: { revision })
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
        let revision = UUID()
        let session = DocumentInputSession(view: view, prepareChange: { _ in
            prepared = true
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, initialDocumentRevision: revision, documentRevision: { revision })
        XCTAssertTrue(session.isStale)
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertFalse(prepared)
        XCTAssertEqual(view.content.string, "original")
    }

    func testPreparedChangesRequireDocumentRevisionProvider() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "original", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var prepared = false
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            prepared = true
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, initialDocumentRevision: UUID())
        XCTAssertTrue(session.isStale)
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertFalse(prepared)
        XCTAssertEqual(view.content.string, "original")
    }

    func testPreparedChangesRequireSnapshotRevision() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "original", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let revision = UUID()
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            .init(publish: {}, finish: {}, reconcile: { _ in })
        }, documentRevision: { revision })
        XCTAssertTrue(session.isStale)
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(view.content.string, "original")
    }

    func testSnapshotRevisionIsCheckedEvenIfDocumentChangedBeforeSessionCreation() throws {
        let snapshotRevision = UUID()
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "old", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let currentRevision = UUID() // The document changed after the snapshot was captured.
        var prepared = false
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            prepared = true
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, initialDocumentRevision: snapshotRevision, documentRevision: { currentRevision })
        XCTAssertFalse(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertFalse(prepared)
        XCTAssertEqual(view.content.string, "old")
    }

    func testPublicationWithoutRevisionAdvanceUsesConflictPath() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "original", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let revision = UUID()
        var finishes = 0
        var conflicts = 0
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            .init(publish: {}, finish: { finishes += 1 }, reconcile: { phase in
                XCTAssertEqual(phase, .beforeFinish)
                conflicts += 1
            })
        }, initialDocumentRevision: revision, documentRevision: { revision })
        XCTAssertTrue(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertEqual(finishes, 0)
        XCTAssertEqual(conflicts, 1)
        XCTAssertFalse(session.insertText("y", replacementRange: unspecified, attributes: attributes))
    }

    func testReentrantDocumentEditDuringLayoutUsesConflictPathBeforeUndoFinish() throws {
        let original = String(repeating: "line\n", count: 100)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original, attributes: attributes))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let permit = try XCTUnwrap(view.claimInputMutation())
        var revision = UUID()
        var canonical = original
        var finishes = 0
        var conflicts = 0
        var acceptedCallbacks = 0
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let accepted = candidate.string
            return .init(publish: { canonical = accepted; revision = UUID() }, finish: { finishes += 1 }, reconcile: { phase in
                XCTAssertEqual(phase, .beforeFinish)
                conflicts += 1
            })
        }, initialDocumentRevision: revision, documentRevision: { revision })
        session.contentDidChange = { _ in acceptedCallbacks += 1 }
        view.postsFrameChangedNotifications = true
        var observed = false
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
            guard !observed else { return }
            observed = true
            canonical = "newer"
            revision = UUID()
        }
        XCTAssertTrue(session.insertText("short", replacementRange: NSRange(location: 0, length: original.utf16.count), attributes: attributes))
        NotificationCenter.default.removeObserver(observer)
        XCTAssertTrue(observed)
        XCTAssertEqual(canonical, "newer")
        XCTAssertEqual(finishes, 0)
        XCTAssertEqual(conflicts, 1)
        XCTAssertEqual(acceptedCallbacks, 0)
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertFalse(session.insertText("later", replacementRange: unspecified, attributes: attributes))
    }

    func testDocumentChangeDuringAcceptedCallbackUsesTicketReconciliation() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "a", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var revision = UUID()
        var canonical = "a"
        var finishes = 0
        var conflicts = 0
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let accepted = candidate.string
            return .init(publish: { canonical = accepted; revision = UUID() }, finish: { finishes += 1 }, reconcile: { phase in
                XCTAssertEqual(phase, .afterNotification)
                conflicts += 1
            })
        }, initialDocumentRevision: revision, documentRevision: { revision })
        session.contentDidChange = { _ in canonical = "newer"; revision = UUID() }
        XCTAssertTrue(session.insertText("x", replacementRange: unspecified, attributes: attributes))
        XCTAssertEqual(canonical, "newer")
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(conflicts, 1)
        XCTAssertTrue(session.hasDocumentConflict)
        XCTAssertFalse(session.insertText("later", replacementRange: unspecified, attributes: attributes))
    }

    func testAttributeOnlyReplacementDoesNotCreateDocumentUndo() throws {
        let owner = AttributeDocumentOwner(text: "x")
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: owner.text, attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        let initialRevision = owner.revision
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let previous = owner.text
            let result = candidate.string
            guard !result.utf16.elementsEqual(previous.utf16) else {
                return .init(publish: {}, finish: {}, reconcile: { _ in })
            }
            return .init(publish: { owner.text = result; owner.revision = UUID() }, finish: {
                owner.undo.beginUndoGrouping()
                owner.undo.registerUndo(withTarget: owner) { $0.text = previous; $0.revision = UUID() }
                owner.undo.endUndoGrouping()
            }, reconcile: { _ in })
        }, initialDocumentRevision: owner.revision, documentRevision: { owner.revision })
        let changed = NSAttributedString(string: "x", attributes: [.font: NSFont.systemFont(ofSize: 24)])
        XCTAssertTrue(session.insertText(changed, replacementRange: NSRange(location: 0, length: 1)))
        XCTAssertEqual(owner.text, "x")
        XCTAssertEqual(owner.revision, initialRevision)
        XCTAssertFalse(owner.undo.canUndo)
        XCTAssertEqual(owner.undo.groupingLevel, 0)
        XCTAssertEqual((view.content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 24)
        XCTAssertFalse(session.hasDocumentConflict)
    }

    func testIdenticalReplacementDoesNotPrepareOrPublish() throws {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "x", attributes: attributes))
        let permit = try XCTUnwrap(view.claimInputMutation())
        var prepared = false
        let revision = UUID()
        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { _ in
            prepared = true
            return .init(publish: {}, finish: {}, reconcile: { _ in })
        }, initialDocumentRevision: revision, documentRevision: { revision })
        XCTAssertTrue(session.insertText("x", replacementRange: NSRange(location: 0, length: 1), attributes: attributes))
        XCTAssertFalse(prepared)
        XCTAssertEqual(session.selectedRange, NSRange(location: 1, length: 0))
    }
}

private final class AttributeDocumentOwner: NSObject {
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
