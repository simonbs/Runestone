#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputSelectionRecoveryTests: XCTestCase {
    func testUnchangedCanonicalSnapshotPreservesUnicodeSelection() throws {
        let fixture = try SelectionRecoveryFixture("A😀\r\ne\u{301}Z")
        let selection = NSRange(location: 1, length: 2)
        XCTAssertEqual(fixture.adapter.setSelection(selection), .processed)
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), selection)
        XCTAssertEqual(fixture.view.content.string, fixture.owner.snapshot.string)
        XCTAssertEqual(fixture.owner.preparations, 0)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testChangedCanonicalRevisionOrSnapshotDiscardsOldSelection() throws {
        for change in 0..<3 {
            let fixture = try SelectionRecoveryFixture("A😀\r\nZ")
            XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 2)), .processed)
            switch change {
            case 0: fixture.owner.revision = UUID() // Same text with a new revision is still a new state.
            case 1: fixture.owner.snapshot = NSAttributedString(string: "changed")
            default:
                fixture.owner.snapshot = NSAttributedString(string: "A😀\r\nZ", attributes: [.foregroundColor: NSColor.red])
            }
            XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
            XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
            XCTAssertEqual(fixture.view.content.string, fixture.owner.snapshot.string)
            XCTAssertEqual(fixture.owner.preparations, 0)
            XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        }
    }

    func testReconstructionRejectsSelectionInsideCRLFOrComposedCharacter() throws {
        for invalidOffset in [4, 6] {
            let fixture = try SelectionRecoveryFixture("A😀\r\ne\u{301}Z")
            // The text-input client allows scalar-boundary selections. They
            // must not be restored as editor carets inside CRLF or a grapheme.
            XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: invalidOffset, length: 0)), .processed)
            XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
            XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
            XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        }
        let fixture = try SelectionRecoveryFixture("A😀\r\ne\u{301}Z")
        XCTAssertNotEqual(fixture.adapter.setSelection(NSRange(location: 2, length: 0)), .processed)
        XCTAssertEqual(fixture.view.content.string, fixture.owner.snapshot.string)
        // An invalid input operation requests reset; reconstruct before detach.
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testDiscardedCompositionRestoresItsPrecompositionSelection() throws {
        let fixture = try SelectionRecoveryFixture("A😀\r\ne\u{301}Z")
        let originalSelection = NSRange(location: 1, length: 2)
        XCTAssertEqual(fixture.adapter.setSelection(originalSelection), .processed)
        XCTAssertEqual(fixture.adapter.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        XCTAssertEqual(fixture.view.content.string, "A仮\r\ne\u{301}Z")
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(fixture.view.content.string, fixture.owner.snapshot.string)
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), originalSelection)
        XCTAssertEqual(fixture.adapter.markedRangeForInput().location, NSNotFound)
        XCTAssertEqual(fixture.owner.preparations, 0)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testCompositionSelectionIsNotRestoredForNewerDocument() throws {
        let fixture = try SelectionRecoveryFixture("A😀\r\nZ")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 2)), .processed)
        XCTAssertEqual(fixture.adapter.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)), .processed)
        fixture.owner.snapshot = NSAttributedString(string: "new document")
        fixture.owner.revision = UUID()
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertEqual(fixture.view.content.string, "new document")
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: 0, length: 0))
        XCTAssertEqual(fixture.adapter.markedRangeForInput().location, NSNotFound)
        XCTAssertEqual(fixture.owner.preparations, 0)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }
}

private final class SelectionRecoveryOwner {
    var snapshot: NSAttributedString
    var revision = UUID()
    var preparations = 0
    init(_ text: String) { snapshot = NSAttributedString(string: text) }
}

private final class SelectionRecoveryFixture {
    let owner: SelectionRecoveryOwner
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter

    init(_ text: String) throws {
        let owner = SelectionRecoveryOwner(text)
        let view = ReadOnlyDocumentView(content: owner.snapshot)
        let adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { _ in .reserved(.init(prepare: { _ in owner.preparations += 1; return nil }, close: {})) },
            beginReconstruction: { .reserved(.init(snapshot: owner.snapshot, revision: owner.revision, close: {})) },
            requestReset: {}))
        self.owner = owner
        self.view = view
        self.adapter = adapter
    }
}
#endif
