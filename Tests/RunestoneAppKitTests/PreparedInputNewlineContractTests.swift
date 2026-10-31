#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputNewlineContractTests: XCTestCase {
    private let unspecified = NSRange(location: NSNotFound, length: 0)

    func testLogicalNewlineUsesExistingStyleAtLineBoundaries() throws {
        for (initial, location, expected) in [
            ("", 0, "\n"),
            ("ab\ncd", 1, "a\nb\ncd"),
            ("ab\r\ncd", 1, "a\r\nb\r\ncd"),
            ("ab\rcd", 1, "a\rb\rcd"),
            ("a\r\nb", 0, "\r\na\r\nb"),
            ("a\r\nb", 3, "a\r\n\r\nb")
        ] {
            let fixture = try NewlineFixture(initial)
            XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: location, length: 0)), .processed)
            let previousRevision = fixture.owner.revision
            XCTAssertEqual(fixture.command("insertNewline:"), .processed, initial.debugDescription)
            XCTAssertEqual(fixture.owner.text, expected, initial.debugDescription)
            XCTAssertEqual(Array(fixture.owner.text.utf8), Array(expected.utf8))
            XCTAssertNotEqual(fixture.owner.revision, previousRevision)
            let insertedLength = (expected as NSString).length - (initial as NSString).length
            XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: location + insertedLength, length: 0))
            XCTAssertTrue(fixture.owner.undo.canUndo)
            XCTAssertEqual(fixture.owner.starts, fixture.owner.closes)
            XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        }
    }

    func testMixedStyleUsesLocalContextForSelectionReplacementWithoutChangingOtherDelimiters() throws {
        let original = "A\r\nSELECT\r\nC\nD\nE\nZ\u{2028}Q\u{2029}"
        let fixture = try NewlineFixture(original)
        let selection = (original as NSString).range(of: "SELECT")
        XCTAssertEqual(fixture.adapter.setSelection(selection), .processed)
        XCTAssertEqual(fixture.command("insertNewline:"), .processed)
        let expected = "A\r\n\r\n\r\nC\nD\nE\nZ\u{2028}Q\u{2029}"
        XCTAssertEqual(fixture.owner.text, expected)
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(expected.utf8))
        XCTAssertEqual(fixture.adapter.selectedRangeForInput(), NSRange(location: selection.location + 2, length: 0))
        XCTAssertEqual(fixture.owner.publications, 1)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testExplicitLineBreakInsertsUnicodeLineSeparator() throws {
        let fixture = try NewlineFixture("A\r\nB")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        XCTAssertEqual(fixture.command("insertLineBreak:"), .processed)
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array("A\u{2028}\r\nB".utf8))
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testUndoRedoRestoresExactMixedEndingDocumentAndRejectsOldRevision() throws {
        let initial = "🐈A\r\nB\r\nC\nD\rE\u{2028}F\u{2029}"
        let fixture = try NewlineFixture(initial)
        let location = (initial as NSString).range(of: "B").location
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: location, length: 0)), .processed)
        let first = fixture.owner.revision
        XCTAssertEqual(fixture.command("insertNewline:"), .processed)
        let edited = "🐈A\r\n\r\nB\r\nC\nD\rE\u{2028}F\u{2029}"
        XCTAssertEqual(fixture.owner.text, edited)
        let committed = fixture.owner.revision
        XCTAssertNotEqual(first, committed)
        XCTAssertTrue(fixture.owner.undo.canUndo)
        fixture.owner.undo.undo()
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(initial.utf8))
        let undone = fixture.owner.revision
        XCTAssertNotEqual(undone, committed)
        XCTAssertNotEqual(fixture.command("insertNewline:"), .processed)
        XCTAssertEqual(fixture.owner.text, initial)
        XCTAssertTrue(fixture.owner.undo.canRedo)
        fixture.owner.undo.redo()
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(edited.utf8))
        XCTAssertNotEqual(fixture.owner.revision, undone)
        XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testDirectReplacementPreservesMixedPasteAndBareLF() throws {
        let original = "before\r\nafter"
        let fixture = try NewlineFixture(original)
        let range = (original as NSString).range(of: "after")
        let paste = "一\r\ntwo\nthree\rfour\u{2028}five\u{2029}"
        XCTAssertEqual(fixture.adapter.insertText(paste, replacementRange: range), .processed)
        let expected = "before\r\n" + paste
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(expected.utf8))
        XCTAssertEqual(fixture.adapter.insertText("\n", replacementRange: unspecified), .processed)
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array((expected + "\n").utf8))
        XCTAssertEqual(fixture.owner.publications, 2)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testMarkedUpdatesAndCommitAreLiteralAndNewlineCommandIsBlocked() throws {
        let fixture = try NewlineFixture("A\r\nB")
        XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        let marked = "日\n本\r\n語\u{2028}"
        XCTAssertEqual(fixture.adapter.setMarkedText(marked,
            selectedRange: NSRange(location: (marked as NSString).length, length: 0), replacementRange: unspecified), .processed)
        XCTAssertEqual(fixture.owner.text, "A\r\nB")
        XCTAssertEqual(fixture.commandReporting("insertNewline:"),
                       .blocked(.init(reason: .compositionActive, effect: .notApplied)))
        XCTAssertEqual(fixture.view.content.string, "A" + marked + "\r\nB")
        XCTAssertEqual(fixture.adapter.insertText(marked, replacementRange: unspecified), .processed)
        XCTAssertEqual(Array(fixture.owner.text.utf8), Array(("A" + marked + "\r\nB").utf8))
        XCTAssertEqual(fixture.owner.publications, 1)
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
    }

    func testBusyAndStaleNewlineAreNotReplayedAgainstCanonicalDocument() throws {
        for stale in [false, true] {
            let fixture = try NewlineFixture("A\r\nB")
            XCTAssertEqual(fixture.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
            if stale {
                fixture.owner.text = "new\nstate"
                fixture.owner.revision = UUID()
            } else {
                fixture.owner.busy = true
            }
            XCTAssertNotEqual(fixture.command("insertNewline:"), .processed)
            XCTAssertEqual(fixture.owner.text, stale ? "new\nstate" : "A\r\nB")
            XCTAssertEqual(fixture.owner.publications, 0)
            XCTAssertFalse(fixture.owner.undo.canUndo)
            fixture.owner.busy = false
            XCTAssertEqual(fixture.adapter.reconstructWithoutInputContext(), .processed)
            XCTAssertEqual(fixture.owner.text, stale ? "new\nstate" : "A\r\nB")
            XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        }
    }

    func testRetiredAdapterDoesNotAcceptNewlineCommand() throws {
        let fixture = try NewlineFixture("A\r\nB")
        XCTAssertTrue(fixture.adapter.disconnectAfterQuiescing())
        XCTAssertNotEqual(fixture.command("insertNewline:"), .processed)
        XCTAssertEqual(fixture.owner.text, "A\r\nB")
        XCTAssertEqual(fixture.owner.publications, 0)
        XCTAssertFalse(fixture.owner.undo.canUndo)
    }
}

private final class NewlineFixture {
    let owner: NewlineOwner
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter

    init(_ text: String) throws {
        let owner = NewlineOwner(text)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: text))
        self.owner = owner
        self.view = view
        adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.reconstruct() }, requestReset: {}))
    }

    func command(_ name: String) -> PreparedInputEventAdapter.Outcome? {
        PreparedInputCommandInterpreter.perform(NSSelectorFromString(name), adapter: adapter, view: view)
    }

    func commandReporting(_ name: String) -> PreparedInputCommandInterpreter.Result {
        PreparedInputCommandInterpreter.performReporting(NSSelectorFromString(name), adapter: adapter, view: view)
    }
}

private final class NewlineOwner {
    var text: String
    var revision = UUID()
    var busy = false
    var starts = 0
    var closes = 0
    var publications = 0
    let undo = UndoManager()

    init(_ text: String) {
        self.text = text
        undo.groupsByEvent = false
    }

    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard expected == revision else { return .stale }
        guard !busy else { return .busy }
        busy = true
        starts += 1
        return .reserved(.init(prepare: { [self] candidate in
            let previous = text
            let next = candidate.string
            return .init(publish: { [self] in
                text = next
                revision = UUID()
                publications += 1
            }, finish: { [self] in
                undo.beginUndoGrouping()
                undo.registerUndo(withTarget: self) { $0.restore(previous) }
                undo.endUndoGrouping()
            }, reconcile: { _ in XCTFail("Unexpected reconciliation") })
        }, close: { [self] in busy = false; closes += 1 }))
    }

    private func restore(_ value: String) {
        let previous = text
        undo.registerUndo(withTarget: self) { $0.restore(previous) }
        text = value
        revision = UUID()
    }

    func reconstruct() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision,
                               close: { [self] in busy = false }))
    }
}
#endif
