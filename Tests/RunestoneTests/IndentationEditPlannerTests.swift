@testable import Runestone
import XCTest

final class IndentationEditPlannerTests: XCTestCase {
    func testShiftRightIndentsEveryLineAndPreservesUTF16Selection() throws {
        let lines = [
            IndentationLine(range: NSRange(location: 0, length: 5), text: "😀a\n"),
            IndentationLine(range: NSRange(location: 5, length: 2), text: "b\n")
        ]

        let edit = try XCTUnwrap(IndentationEditPlanner.shiftRight(
            lines: lines, selectedRange: NSRange(location: 2, length: 4), indentString: "  "))

        XCTAssertEqual(edit, IndentationEdit(
            replacementRange: NSRange(location: 0, length: 7),
            replacementText: "  😀a\n  b\n",
            selectedRange: NSRange(location: 4, length: 6)))
    }

    func testShiftLeftClampsSelectionToFirstLineAndSkipsUnindentedLines() throws {
        let lines = [
            IndentationLine(range: NSRange(location: 10, length: 6), text: "  one\n"),
            IndentationLine(range: NSRange(location: 16, length: 4), text: "two\n"),
            IndentationLine(range: NSRange(location: 20, length: 8), text: "  three\n")
        ]

        let edit = try XCTUnwrap(IndentationEditPlanner.shiftLeft(
            lines: lines, selectedRange: NSRange(location: 11, length: 15), indentString: "  "))

        XCTAssertEqual(edit, IndentationEdit(
            replacementRange: NSRange(location: 10, length: 18),
            replacementText: "one\ntwo\nthree\n",
            selectedRange: NSRange(location: 10, length: 12)))
    }

    func testShiftPlanningReturnsNilWithoutLines() {
        let emptyRange = NSRange(location: 0, length: 0)
        XCTAssertNil(IndentationEditPlanner.shiftLeft(lines: [], selectedRange: emptyRange, indentString: "  "))
        XCTAssertNil(IndentationEditPlanner.shiftRight(lines: [], selectedRange: emptyRange, indentString: "  "))
    }

    func testExtraLineBreakPlacesCaretInsideIndentedBlock() {
        let edit = IndentationEditPlanner.insertLineBreak(
            in: NSRange(location: 4, length: 0), symbol: "\r\n",
            indentString: "    ", previousIndentString: "")

        XCTAssertEqual(edit, IndentationEdit(
            replacementRange: NSRange(location: 4, length: 0),
            replacementText: "\r\n    \r\n",
            selectedRange: NSRange(location: 10, length: 0)))
    }

    func testOrdinaryLineBreakDoesNotRequestSelectionChange() {
        let edit = IndentationEditPlanner.insertLineBreak(
            in: NSRange(location: 3, length: 2), symbol: "\n", indentString: "\t")

        XCTAssertEqual(edit, IndentationEdit(
            replacementRange: NSRange(location: 3, length: 2),
            replacementText: "\n\t",
            selectedRange: nil))
    }

    func testIndentDeletionRequiresCompleteLevelWithinLeadingIndent() {
        XCTAssertEqual(IndentationEditPlanner.indentRange(
            inFrontOf: 18, lineLocation: 10, currentIndentLength: 8, tabLength: 4),
        NSRange(location: 14, length: 4))
        XCTAssertNil(IndentationEditPlanner.indentRange(
            inFrontOf: 16, lineLocation: 10, currentIndentLength: 8, tabLength: 4))
        XCTAssertNil(IndentationEditPlanner.indentRange(
            inFrontOf: 22, lineLocation: 10, currentIndentLength: 8, tabLength: 4))
        XCTAssertNil(IndentationEditPlanner.indentRange(
            inFrontOf: 18, lineLocation: 10, currentIndentLength: 8, tabLength: 0))
    }
}
