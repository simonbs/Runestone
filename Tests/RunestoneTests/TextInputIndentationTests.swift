@testable import Runestone
import XCTest

final class TextInputIndentationTests: XCTestCase {
    func testTypedTabUsesSpacesAtCaretWithSpaceIndentation() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.indentStrategy = .space(length: 4)
        textInputView.insertText("key: value")
        textInputView.selectedRange = NSRange(location: 5, length: 0)
        textInputView.insertText("\t")
        XCTAssertEqual(textInputView.string as String, "key:     value")
        XCTAssertEqual(textInputView.selectedRange, NSRange(location: 9, length: 0))
    }

    func testTypedTabUsesLiteralTabWithTabIndentation() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.indentStrategy = .tab(length: 4)
        textInputView.insertText("\t")
        XCTAssertEqual(textInputView.string as String, "\t")
        XCTAssertEqual(textInputView.selectedRange, NSRange(location: 1, length: 0))
    }

    func testLiteralTabsArePreservedInReplacementAndMulticharacterInsertion() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.indentStrategy = .space(length: 4)
        textInputView.replace(IndexedRange(location: 0, length: 0), withText: "\t")
        textInputView.insertText("one\ttwo")
        XCTAssertEqual(textInputView.string as String, "\tone\ttwo")
    }

    func testMultilineShiftRoundTripAppliesPlannedTextAndSelection() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.indentStrategy = .space(length: 4)
        textInputView.insertText("one\ntwo")
        textInputView.selectedRange = NSRange(location: 0, length: 7)

        textInputView.shiftRight()

        XCTAssertEqual(textInputView.string as String, "    one\n    two")
        XCTAssertEqual(textInputView.selectedRange, NSRange(location: 4, length: 11))

        textInputView.shiftLeft()

        XCTAssertEqual(textInputView.string as String, "one\ntwo")
        XCTAssertEqual(textInputView.selectedRange, NSRange(location: 0, length: 7))
    }
}
