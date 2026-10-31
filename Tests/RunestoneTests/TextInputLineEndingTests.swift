@testable import Runestone
import XCTest

final class TextInputLineEndingTests: XCTestCase {
    func testArbitraryInsertedTextPreservesEveryExplicitLineEnding() {
        for configuredEnding in [LineEnding.lf, .cr, .crlf] {
            let input = TextInputView(theme: DefaultTheme())
            input.lineEndings = configuredEnding
            let inserted = "First 🥳\r\nSecond\rThird\nFourth\u{2028}Fifth\u{2029}"
            input.insertText(inserted)
            XCTAssertEqual(input.string as String, inserted)
            XCTAssertEqual(input.selectedRange, NSRange(location: inserted.utf16.count, length: 0))
        }
    }

    func testGenericStandaloneLFIsLiteralWhenOriginIsUnknown() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "first\r\nsecond"
        input.selectedRange = NSRange(location: 5, length: 0)
        input.lineEndings = .crlf
        input.insertText("\n")
        XCTAssertEqual(input.string as String, "first\n\r\nsecond")
    }

    func testSystemReplacementPreservesMixedLineEndings() throws {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "before after"
        input.selectedRange = NSRange(location: 7, length: 5)
        let range = try XCTUnwrap(input.selectedTextRange)
        input.replace(range, withText: "a\r\nb\rc\nd\u{2028}e\u{2029}")
        XCTAssertEqual(input.string as String, "before a\r\nb\rc\nd\u{2028}e\u{2029}")
    }

    func testIdentifiedNewlineUsesContextAndReplacesSelection() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "😀one\r\ntwo\r\n"
        input.selectedRange = NSRange(location: 2, length: 3)
        XCTAssertTrue(input.insertLogicalNewline())
        XCTAssertEqual(input.string as String, "😀\r\n\r\ntwo\r\n")
        XCTAssertEqual(input.selectedRange, NSRange(location: 4, length: 0))
    }

    func testPublicLogicalNewlineUsesContextAndUpdatesSelection() {
        let view = TextView()
        view.text = "first\r\nsecond"
        view.lineEndings = .lf
        view.selectedRange = NSRange(location: 5, length: 0)
        XCTAssertTrue(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "first\r\n\r\nsecond")
        XCTAssertEqual(view.selectedRange, NSRange(location: 7, length: 0))
    }

    func testIdentifiedNewlineRejectsSurrogateSplitWithoutMutation() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "A😀B\r\n"
        input.selectedRange = NSRange(location: 2, length: 0)
        XCTAssertFalse(input.insertLogicalNewline())
        XCTAssertEqual(input.string as String, "A😀B\r\n")
        XCTAssertEqual(input.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertFalse(input.undoManager?.canUndo == true)
    }

    func testIdentifiedNewlineDoesNotOverwriteActiveMarkedText() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "a\r\nb"
        input.selectedRange = NSRange(location: 1, length: 0)
        input.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertFalse(input.insertLogicalNewline())
        XCTAssertEqual(input.string as String, "a仮\r\nb")
        XCTAssertNotNil(input.markedTextRange)
    }

    func testMarkedCommitPreservesLiteralInput() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "a\r\nb"
        input.selectedRange = NSRange(location: 1, length: 0)
        input.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0))
        input.insertText("x\ny\rz")
        XCTAssertEqual(input.string as String, "ax\ny\rz\r\nb")
    }
}
