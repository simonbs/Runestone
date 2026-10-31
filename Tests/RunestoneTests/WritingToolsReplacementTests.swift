@testable import Runestone
import XCTest

final class WritingToolsReplacementTests: XCTestCase {
    func testUnicodeReplacementPreservesLineEndingsAndUndoAndRedo() throws {
        let view = TextView()
        let originalText = "Before 👩🏽‍💻 after\r\nLast"
        let range = (originalText as NSString).range(of: "👩🏽‍💻")
        view.text = originalText
        view.lineEndings = .crlf
        view.selectedRange = range
        let recorder = WritingToolsEditRecorder()
        view.editorDelegate = recorder
        let input = try textInput(in: view)

        let result = input.replaceTextForWritingTools(in: range, with: "Café\n你好\rDone")

        XCTAssertEqual(result, "Café\n你好\rDone")
        let expectedText = "Before Café\n你好\rDone after\r\nLast"
        XCTAssertEqual(view.text, expectedText)
        XCTAssertEqual(view.selectedRange, NSRange(location: range.location + (result ?? "").utf16.count, length: 0))
        XCTAssertEqual(recorder.changedTexts, [expectedText])
        XCTAssertEqual(recorder.proposedTexts, ["Café\n你好\rDone"])

        let undoManager = try XCTUnwrap(view.undoManager)
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()
        XCTAssertEqual(view.text, originalText)
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()
        XCTAssertEqual(view.text, expectedText)
        XCTAssertEqual(view.selectedRange, NSRange(location: range.location + (result ?? "").utf16.count, length: 0))
    }

    func testInvalidUTF16RangesDoNotChangeTextSelectionOrUndoHistory() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "A😀B"
        let selection = NSRange(location: 1, length: 2)
        input.selectedRange = selection
        let invalidRanges = [
            NSRange(location: 2, length: 0), // Splits the emoji's surrogate pair.
            NSRange(location: 1, length: 1),
            NSRange(location: 2, length: 1),
            NSRange(location: 5, length: 0),
            NSRange(location: 3, length: 2),
            NSRange(location: NSNotFound, length: 1),
            NSRange(location: 1, length: Int.max)
        ]
        for range in invalidRanges {
            XCTAssertNil(input.replaceTextForWritingTools(in: range, with: "replacement"), "Range: \(range)")
            XCTAssertEqual(input.string, "A😀B")
            XCTAssertEqual(input.selectedRange, selection)
            XCTAssertFalse(input.undoManager?.canUndo == true)
        }
    }

    func testReadOnlyAndDelegateVetoPreventWritingToolsEdits() throws {
        let view = TextView()
        view.text = "Keep this text"
        let range = NSRange(location: 0, length: 4)
        view.selectedRange = range
        let recorder = WritingToolsEditRecorder()
        view.editorDelegate = recorder
        let input = try textInput(in: view)

        view.isEditable = false
        XCTAssertNil(input.replaceTextForWritingTools(in: range, with: "Change"))
        XCTAssertEqual(view.text, "Keep this text")
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertFalse(view.undoManager?.canUndo == true)

        view.isEditable = true
        recorder.allowsChanges = false
        XCTAssertNil(input.replaceTextForWritingTools(in: range, with: "Change"))
        XCTAssertEqual(recorder.proposedTexts.last, "Change")
        XCTAssertEqual(view.text, "Keep this text")
        XCTAssertEqual(view.selectedRange, range)
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    func testWritingToolsPunctuationIsInsertedLiterallyWithoutCharacterPairExpansion() throws {
        let view = TextView()
        view.text = "word"
        view.characterPairs = [WritingToolsQuotePair()]
        view.selectedRange = NSRange(location: 0, length: 4)
        let input = try textInput(in: view)

        XCTAssertEqual(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 4), with: "'"), "'")

        XCTAssertEqual(view.text, "'")
        XCTAssertEqual(view.selectedRange, NSRange(location: 1, length: 0))
    }

    func testDelegateChangingDocumentDuringApprovalDoesNotApplyAnOldReplacement() throws {
        let view = TextView()
        view.text = "original"
        view.selectedRange = NSRange(location: 0, length: 8)
        let recorder = WritingToolsEditRecorder()
        recorder.onApproval = { $0.text = "new file" }
        view.editorDelegate = recorder
        let input = try textInput(in: view)

        XCTAssertNil(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 8), with: "rewritten"))

        XCTAssertEqual(view.text, "new file")
        XCTAssertTrue(recorder.changedTexts.isEmpty)
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    func testWritingToolsDoesNotOverwriteInProgressIMEComposition() {
        let input = TextInputView(theme: DefaultTheme())
        input.string = "Hello "
        input.selectedRange = NSRange(location: 6, length: 0)
        input.setMarkedText("你好", selectedRange: NSRange(location: 2, length: 0))
        let selectedRange = input.selectedRange

        XCTAssertNil(input.replaceTextForWritingTools(in: NSRange(location: 0, length: 5), with: "Hi"))

        XCTAssertEqual(input.string, "Hello 你好")
        XCTAssertNotNil(input.markedTextRange)
        XCTAssertEqual(input.selectedRange, selectedRange)
    }

    private func textInput(in textView: TextView) throws -> TextInputView {
        try XCTUnwrap(textView.subviews.compactMap { $0 as? TextInputView }.first)
    }
}

private final class WritingToolsEditRecorder: TextViewDelegate {
    var allowsChanges = true
    var onApproval: ((TextView) -> Void)?
    var proposedTexts: [String] = []
    var changedTexts: [String] = []

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        proposedTexts.append(text)
        onApproval?(textView)
        return allowsChanges
    }

    func textViewDidChange(_ textView: TextView) {
        changedTexts.append(textView.text)
    }
}

private struct WritingToolsQuotePair: CharacterPair {
    let leading = "'"
    let trailing = "'"
}
