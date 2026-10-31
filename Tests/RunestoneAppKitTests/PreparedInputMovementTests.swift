#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputMovementTests: XCTestCase {
    func testExtendedMovementRetainsAnchorWhenReversingAndCrossingIt() throws {
        let f = try MovementFixture("abcdef")
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 3, length: 0)), .processed)
        for (selector, expected) in [
            ("moveLeftAndModifySelection:", NSRange(location: 2, length: 1)),
            ("moveLeftAndModifySelection:", NSRange(location: 1, length: 2)),
            ("moveRightAndModifySelection:", NSRange(location: 2, length: 1)),
            ("moveRightAndModifySelection:", NSRange(location: 3, length: 0)),
            ("moveRightAndModifySelection:", NSRange(location: 3, length: 1)),
            ("moveLeftAndModifySelection:", NSRange(location: 3, length: 0))
        ] {
            XCTAssertEqual(f.run(selector), .processed, selector)
            XCTAssertEqual(f.adapter.selectedRangeForInput(), expected, selector)
        }
        XCTAssertEqual(f.owner.text, "abcdef")
        XCTAssertEqual(f.owner.undoCount, 0)
        XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
    }

    func testViewportGeometryChangePreservesExtensionAnchor() throws {
        let f = try MovementFixture("abcdef")
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 3, length: 0)), .processed)
        XCTAssertEqual(f.run("moveLeftAndModifySelection:"), .processed)
        f.view.noteInputCoordinatesChanged() // Geometry can change without a selection change.
        XCTAssertEqual(f.run("moveRightAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput(), NSRange(location: 3, length: 0))
        XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
    }

    func testExternalSelectionAwayAndBackInvalidatesOldAnchor() throws {
        let f = try MovementFixture("abcdef")
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 3, length: 0)), .processed)
        XCTAssertEqual(f.run("moveLeftAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 0, length: 0)), .processed)
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 2, length: 1)), .processed)
        XCTAssertEqual(f.run("moveRightAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput(), NSRange(location: 2, length: 2))
        XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
    }

    func testExternalSelectionReplacesExtensionAnchor() throws {
        let f = try MovementFixture("abcdef")
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 4, length: 0)), .processed)
        XCTAssertEqual(f.run("moveLeftAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: 0, length: 2)), .processed)
        XCTAssertEqual(f.run("moveRightAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput(), NSRange(location: 0, length: 3))
        XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
    }

    func testWordMovementAndDeletionKeepEmojiAndCRLFWhole() throws {
        let original = "one 🐈 two\r\nthree"
        let f = try MovementFixture(original)
        let length = (original as NSString).length
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: length, length: 0)), .processed)
        XCTAssertEqual(f.run("moveWordBackward:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput().location, (original as NSString).range(of: "three").location)
        XCTAssertEqual(f.run("deleteWordBackward:"), .processed)
        XCTAssertEqual(f.owner.text, "one 🐈 three")
        XCTAssertEqual(f.owner.undoCount, 1)
        XCTAssertEqual(f.run("moveWordBackward:"), .processed)
        let emojiLocation = (f.owner.text as NSString).range(of: "🐈").location
        XCTAssertEqual(f.adapter.selectedRangeForInput().location, emojiLocation)
        XCTAssertEqual(f.run("deleteWordForward:"), .processed)
        XCTAssertEqual(f.owner.text, "one  three")
        XCTAssertEqual(f.owner.undoCount, 2)
        XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
    }

    func testCombiningAndCRLFInteriorCannotBeDeletedOrExtended() throws {
        for (text, interior) in [("ae\u{301}b", 2), ("a\r\nb", 2)] {
            let f = try MovementFixture(text)
            XCTAssertEqual(f.adapter.setSelection(NSRange(location: interior, length: 0)), .processed)
            for selector in ["deleteWordBackward:", "deleteWordForward:", "moveLeftAndModifySelection:"] {
                XCTAssertEqual(f.reporting(selector), .blocked(.init(reason: .invalidSelection, effect: .notApplied)), selector)
            }
            XCTAssertEqual(Array(f.owner.text.utf8), Array(text.utf8))
            XCTAssertEqual(f.owner.undoCount, 0)
            XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
        }
    }

    func testCharacterMovementAndDeletionTreatCRLFAsOneBoundary() throws {
        let movement = try MovementFixture("a\r\nb")
        XCTAssertEqual(movement.adapter.setSelection(NSRange(location: 1, length: 0)), .processed)
        XCTAssertEqual(movement.run("moveRight:"), .processed)
        XCTAssertEqual(movement.adapter.selectedRangeForInput(), NSRange(location: 3, length: 0))
        XCTAssertEqual(movement.run("moveLeft:"), .processed)
        XCTAssertEqual(movement.adapter.selectedRangeForInput(), NSRange(location: 1, length: 0))
        XCTAssertEqual(movement.run("deleteForward:"), .processed)
        XCTAssertEqual(movement.owner.text, "ab")
        XCTAssertTrue(movement.adapter.disconnectAfterQuiescing())

        let backward = try MovementFixture("a\r\nb")
        XCTAssertEqual(backward.adapter.setSelection(NSRange(location: 3, length: 0)), .processed)
        XCTAssertEqual(backward.run("deleteBackward:"), .processed)
        XCTAssertEqual(backward.owner.text, "ab")
        XCTAssertTrue(backward.adapter.disconnectAfterQuiescing())
    }

    func testParagraphAndDocumentBoundariesPreserveDelimiterContent() throws {
        let text = "a\r\nbb\ncc\u{2029}d"
        let f = try MovementFixture(text)
        let middle = (text as NSString).range(of: "bb").location + 1
        XCTAssertEqual(f.adapter.setSelection(NSRange(location: middle, length: 0)), .processed)
        XCTAssertEqual(f.run("moveToBeginningOfParagraph:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput().location, middle - 1)
        XCTAssertEqual(f.run("moveToEndOfParagraphAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput(), NSRange(location: middle - 1, length: 2))
        XCTAssertEqual(f.run("moveToEndOfDocument:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput(), NSRange(location: (text as NSString).length, length: 0))
        XCTAssertEqual(f.run("moveToBeginningOfDocumentAndModifySelection:"), .processed)
        XCTAssertEqual(f.adapter.selectedRangeForInput(), NSRange(location: 0, length: (text as NSString).length))
        XCTAssertEqual(Array(f.owner.text.utf8), Array(text.utf8))
        XCTAssertTrue(f.adapter.disconnectAfterQuiescing())
    }

    func testMarkedCompositionAndBusyOrStaleRevisionRejectMovement() throws {
        let marked = try MovementFixture("abc")
        XCTAssertEqual(marked.adapter.setMarkedText("", selectedRange: NSRange(location: 0, length: 0),
                                                    replacementRange: NSRange(location: 1, length: 1)), .processed)
        XCTAssertEqual(marked.reporting("moveWordRightAndModifySelection:"),
                       .blocked(.init(reason: .compositionActive, effect: .notApplied)))
        XCTAssertEqual(marked.owner.text, "abc")
        XCTAssertEqual(marked.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(marked.adapter.disconnectAfterQuiescing())

        let busy = try MovementFixture("one two")
        busy.owner.busy = true
        XCTAssertEqual(busy.run("moveWordRight:"), .resetRequired)
        XCTAssertEqual(busy.owner.text, "one two")
        XCTAssertEqual(busy.owner.undoCount, 0)
        busy.owner.busy = false
        XCTAssertEqual(busy.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(busy.adapter.disconnectAfterQuiescing())

        let stale = try MovementFixture("one two")
        stale.owner.text = "new text"
        stale.owner.revision = UUID()
        XCTAssertNotEqual(stale.run("deleteWordForward:"), .processed)
        XCTAssertEqual(stale.owner.text, "new text")
        XCTAssertEqual(stale.owner.undoCount, 0)
        XCTAssertEqual(stale.adapter.reconstructWithoutInputContext(), .processed)
        XCTAssertTrue(stale.adapter.disconnectAfterQuiescing())
    }
}

private final class MovementFixture {
    let owner: MovementOwner
    let view: ReadOnlyDocumentView
    let adapter: PreparedInputEventAdapter
    init(_ text: String) throws {
        let owner = MovementOwner(text)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: text))
        self.owner = owner
        self.view = view
        adapter = try XCTUnwrap(PreparedInputEventAdapter(view: view, snapshot: view.content,
            initialRevision: owner.revision, documentRevision: { owner.revision }, typingAttributes: { [:] },
            beginEvent: { owner.begin($0) }, beginReconstruction: { owner.reconstruct() }, requestReset: {}))
    }
    func run(_ selector: String) -> PreparedInputEventAdapter.Outcome? {
        PreparedInputCommandInterpreter.perform(NSSelectorFromString(selector), adapter: adapter, view: view)
    }
    func reporting(_ selector: String) -> PreparedInputCommandInterpreter.Result {
        PreparedInputCommandInterpreter.performReporting(NSSelectorFromString(selector), adapter: adapter, view: view)
    }
}

private final class MovementOwner {
    var text: String
    var revision = UUID()
    var busy = false
    var undoCount = 0
    init(_ text: String) { self.text = text }
    func begin(_ expected: UUID) -> PreparedInputEventAdapter.ReservationResult {
        guard expected == revision else { return .stale }
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(prepare: { [self] candidate in
            let next = candidate.string
            return .init(publish: { [self] in text = next; revision = UUID() },
                         finish: { [self] in undoCount += 1 }, reconcile: { _ in XCTFail("Unexpected conflict") })
        }, close: { [self] in busy = false }))
    }
    func reconstruct() -> PreparedInputEventAdapter.ReconstructionStart {
        guard !busy else { return .busy }
        busy = true
        return .reserved(.init(snapshot: NSAttributedString(string: text), revision: revision, close: { [self] in busy = false }))
    }
}
#endif
