@testable import Runestone
import UIKit
import XCTest

final class TextInputPasteLineEndingTests: XCTestCase {
    func testPasteActionPreservesSingleLFInCRLFDocumentAndCanUndo() throws {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "a\r\nb"
        input.selectedRange = NSRange(location: 1, length: 0)
        input.pasteboardStringProvider = { "\n" }

        input.paste(nil)

        XCTAssertEqual(input.string as String, "a\n\r\nb")
        XCTAssertEqual(input.selectedRange, NSRange(location: 2, length: 0))
        let undo = try XCTUnwrap(input.undoManager)
        undo.undo()
        XCTAssertEqual(input.string as String, "a\r\nb")
        XCTAssertEqual(input.selectedRange, NSRange(location: 1, length: 0))
        undo.redo()
        XCTAssertEqual(input.string as String, "a\n\r\nb")
    }

    func testPasteActionPreservesMixedLineEndingsWhenReplacingSelection() throws {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "before after"
        input.selectedRange = NSRange(location: 7, length: 5)
        input.pasteboardStringProvider = { "x\r\ny\rz\n" }

        input.paste(nil)

        XCTAssertEqual(input.string as String, "before x\r\ny\rz\n")
        XCTAssertEqual(input.selectedRange, NSRange(location: 14, length: 0))
        let undo = try XCTUnwrap(input.undoManager)
        undo.undo()
        XCTAssertEqual(input.string as String, "before after")
        XCTAssertEqual(input.selectedRange, NSRange(location: 7, length: 5))
    }

    func testPasteRejectsProviderSelectionOrDocumentChanges() {
        for changesDocument in [false, true] {
            let input = TextInputView(theme: DefaultTheme())
            input.string = "a\r\nb"
            input.selectedRange = NSRange(location: 1, length: 0)
            input.pasteboardStringProvider = { [weak input] in
                if changesDocument { input?.string = "updated" }
                else { input?.selectedRange = NSRange(location: 2, length: 0) }
                return "\n"
            }
            input.paste(nil)
            XCTAssertEqual(input.string as String, changesDocument ? "updated" : "a\r\nb")
            if !changesDocument { XCTAssertEqual(input.selectedRange, NSRange(location: 2, length: 0)) }
            XCTAssertFalse(input.undoManager?.canUndo == true)
        }
    }

    func testPastePairsInputNotificationsWhenSelectionChangesDuringWillChange() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "a\r\nb"
        input.selectedRange = NSRange(location: 1, length: 0)
        input.pasteboardStringProvider = { "\n" }
        let recorder = PasteInputDelegate { input.selectedRange = NSRange(location: 2, length: 0) }
        input.inputDelegate = recorder

        input.paste(nil)

        XCTAssertEqual(input.string as String, "a\r\nb")
        XCTAssertEqual(input.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertEqual(recorder.willChanges, 1)
        XCTAssertEqual(recorder.didChanges, 1)
    }

    func testPasteRejectsSelectionChangedByShouldChangeDelegate() throws {
        let view = TextView()
        view.text = "a\r\nb"
        view.selectedRange = NSRange(location: 1, length: 0)
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.pasteboardStringProvider = { "\n" }
        let delegate = PasteEditorDelegate()
        view.editorDelegate = delegate

        input.paste(nil)

        XCTAssertEqual(view.text, "a\r\nb")
        XCTAssertEqual(view.selectedRange, NSRange(location: 2, length: 0))
        XCTAssertFalse(input.undoManager?.canUndo == true)
    }
}

private final class PasteInputDelegate: NSObject, UITextInputDelegate {
    let onWillChange: () -> Void
    var willChanges = 0
    var didChanges = 0
    init(_ onWillChange: @escaping () -> Void) { self.onWillChange = onWillChange }
    func selectionWillChange(_ textInput: UITextInput?) { willChanges += 1; onWillChange() }
    func selectionDidChange(_ textInput: UITextInput?) { didChanges += 1 }
    func textWillChange(_ textInput: UITextInput?) {}
    func textDidChange(_ textInput: UITextInput?) {}
    #if compiler(>=6.1)
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange textInput: UITextInput?) {}
    #endif
}

private final class PasteEditorDelegate: TextViewDelegate {
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        textView.selectedRange = NSRange(location: 2, length: 0)
        return true
    }
}
