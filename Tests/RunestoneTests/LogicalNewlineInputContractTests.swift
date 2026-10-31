@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class LogicalNewlineInputContractTests: XCTestCase {
    func testExplicitNewlineUsesContextAndLanguageIndentationWithUndo() {
        let scopes = TreeSitterIndentationScopes(indent: ["object", "array"], outdent: ["}", "]"])
        let language = TreeSitterLanguage(tree_sitter_json(), indentationScopes: scopes)
        for ending in ["\n", "\r", "\r\n", "\u{0085}", "\u{2028}", "\u{2029}"] {
            let view = TextView()
            let original = "[{}]" + ending
            view.setState(TextViewState(text: original, language: language))
            view.indentStrategy = .space(length: 2)
            view.selectedRange = NSRange(location: 2, length: 0)

            XCTAssertTrue(view.insertLogicalNewline(), "ending: \(ending.debugDescription)")
            let expected = "[{" + ending + "  " + ending + "}]" + ending
            XCTAssertEqual(view.text, expected, "ending: \(ending.debugDescription)")
            XCTAssertEqual(view.selectedRange, NSRange(location: 2 + ending.utf16.count + 2, length: 0))
            view.undoManager?.undo()
            XCTAssertEqual(view.text, original)
            XCTAssertEqual(view.selectedRange, NSRange(location: 2, length: 0))
            view.undoManager?.redo()
            XCTAssertEqual(view.text, expected)
        }
    }

    func testUnknownSingleLFAndLiteralReplacementStayLiteral() {
        let view = TextView()
        view.text = "first\r\nsecond"
        view.selectedRange = NSRange(location: 5, length: 0)
        // UIKeyInput.insertText carries no public Return provenance.
        view.insertText("\n")
        XCTAssertEqual(view.text, "first\n\r\nsecond")

        view.replace(NSRange(location: 5, length: 1), withText: "\n")
        XCTAssertEqual(view.text, "first\n\r\nsecond")
        view.replace(NSRange(location: 5, length: 1), withText: "A\r\nB\rC\n")
        XCTAssertEqual(view.text, "firstA\r\nB\rC\n\r\nsecond")
    }

    func testStandaloneLFCommittingMarkedTextRemainsLiteral() throws {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "a\r\nb"
        input.selectedRange = NSRange(location: 1, length: 0)
        input.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(input.markedTextRange)
        input.insertText("\n")
        XCTAssertEqual(input.string as String, "a\n\r\nb")
        XCTAssertNil(input.markedTextRange)
    }

    func testExplicitNewlineRejectsSelectionChangedByDelegate() {
        let view = TextView()
        view.text = "first\r\nsecond"
        view.selectedRange = NSRange(location: 5, length: 0)
        let delegate = NewlineContractDelegate { textView, _, _ in
            textView.selectedRange = NSRange(location: 0, length: 0)
            return true
        }
        view.editorDelegate = delegate
        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "first\r\nsecond")
        XCTAssertEqual(view.selectedRange, NSRange(location: 0, length: 0))
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    func testDelegateCanHandleNewlineWithoutDefaultEditOrReplay() {
        let view = TextView()
        view.text = "- item\r\nend"
        view.selectedRange = NSRange(location: 6, length: 0)
        let delegate = NewlineContractDelegate { textView, range, text in
            guard text == "\r\n" else { return true }
            textView.replace(range, withText: "\r\n- ")
            return false
        }
        view.editorDelegate = delegate
        // A false return can mean the delegate handled the edit itself.
        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "- item\r\n- \r\nend")
        view.undoManager?.undo()
        XCTAssertEqual(view.text, "- item\r\nend")
        view.undoManager?.redo()
        XCTAssertEqual(view.text, "- item\r\n- \r\nend")
    }
}

private final class NewlineContractDelegate: TextViewDelegate {
    let handle: (TextView, NSRange, String) -> Bool
    init(_ handle: @escaping (TextView, NSRange, String) -> Bool) { self.handle = handle }
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        handle(textView, range, text)
    }
}
