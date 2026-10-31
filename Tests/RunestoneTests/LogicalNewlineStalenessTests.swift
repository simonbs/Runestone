@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class LogicalNewlineStalenessTests: XCTestCase {
    func testDelegateSelectionChangeAndRestoreStillRejectsOldNewline() {
        let view = makeView()
        let delegate = LogicalNewlineDelegate { view in
            view.selectedRange = NSRange(location: 2, length: 0)
            view.selectedRange = NSRange(location: 1, length: 0)
            return true
        }
        view.editorDelegate = delegate
        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "abc\r\ndef")
        XCTAssertEqual(view.selectedRange, NSRange(location: 1, length: 0))
    }

    func testDelegateDocumentChangeRejectsOldNewline() {
        let view = makeView()
        let delegate = LogicalNewlineDelegate { view in
            view.text = "updated\r\ntext"
            return true
        }
        view.editorDelegate = delegate
        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "updated\r\ntext")
    }

    func testDelegateCompositionChangeRejectsOldNewline() throws {
        let view = makeView()
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        var handled = false
        let delegate = LogicalNewlineDelegate { _ in
            if !handled {
                handled = true
                input.setMarkedText("仮", selectedRange: NSRange(location: 1, length: 0))
            }
            return true
        }
        view.editorDelegate = delegate
        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "a仮bc\r\ndef")
        XCTAssertNotNil(view.markedTextRange)
    }

    func testNestedDocumentChangeAfterInsertionReportsInterruption() {
        let view = makeView()
        let delegate = LogicalNewlineDelegate { _ in true }
        var changes = 0
        delegate.onChange = { view in
            changes += 1
            if changes == 1 { view.text = "nested document" }
        }
        view.editorDelegate = delegate
        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "nested document")
        XCTAssertEqual(changes, 1)
    }

    func testDelegateCannotReenterLogicalNewlineCommand() {
        let view = makeView()
        var calls = 0
        var nestedResult: Bool?
        let delegate = LogicalNewlineDelegate { view in
            calls += 1
            if calls == 1 { nestedResult = view.insertLogicalNewline() }
            return true
        }
        view.editorDelegate = delegate

        XCTAssertTrue(view.insertLogicalNewline())
        XCTAssertEqual(nestedResult, false)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(view.text, "a\r\nbc\r\ndef")
        XCTAssertEqual(view.selectedRange, NSRange(location: 3, length: 0))
    }

    func testExtraLineDoesNotOverwriteSelectionChangedDuringInsertion() {
        let scopes = TreeSitterIndentationScopes(indent: ["object", "array"], outdent: ["}", "]"])
        let language = TreeSitterLanguage(tree_sitter_json(), indentationScopes: scopes)
        let view = TextView()
        view.setState(TextViewState(text: "[{}]\r\n", language: language))
        view.indentStrategy = .space(length: 2)
        view.selectedRange = NSRange(location: 2, length: 0)
        let delegate = LogicalNewlineDelegate { _ in true }
        delegate.onChange = { view in view.selectedRange = NSRange(location: 0, length: 0) }
        view.editorDelegate = delegate

        XCTAssertFalse(view.insertLogicalNewline())
        XCTAssertEqual(view.text, "[{\r\n  \r\n}]\r\n")
        XCTAssertEqual(view.selectedRange, NSRange(location: 0, length: 0))
    }

    private func makeView() -> TextView {
        let view = TextView()
        view.text = "abc\r\ndef"
        view.selectedRange = NSRange(location: 1, length: 0)
        return view
    }
}

private final class LogicalNewlineDelegate: TextViewDelegate {
    let onEdit: (TextView) -> Bool
    var onChange: ((TextView) -> Void)?
    init(_ onEdit: @escaping (TextView) -> Bool) { self.onEdit = onEdit }
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        onEdit(textView)
    }
    func textViewDidChange(_ textView: TextView) { onChange?(textView) }
}
