#if os(macOS)
import AppKit

public extension TextView {
    /// Deletes a character from the displayed text.
    override func deleteBackward(_ sender: Any?) {
        guard var selectedRange = textViewController.markedRange ?? textViewController.selectedRange?.nonNegativeLength else {
            return
        }
        if selectedRange.length == 0 {
            selectedRange.location -= 1
            selectedRange.length = 1
        }
        let deleteRange = textViewController.rangeForDeletingText(in: selectedRange)
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == textViewController.markedRange {
            textViewController.markedRange = nil
        }
        guard textViewController.shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
            undoManager?.beginUndoGrouping()
        }
        textViewController.replaceText(in: deleteRange, with: "", selectedRangeAfterUndo: selectedRange)
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
        }
    }

    /// Inserts a newline character.
    override func insertNewline(_ sender: Any?) {
        if textViewController.shouldChangeText(in: textViewController.rangeForInsertingText, replacementText: lineEndings.symbol) {
            textViewController.indentController.insertLineBreak(in: textViewController.rangeForInsertingText, using: lineEndings.symbol)
        }
    }

    /// Inserts a tab character.
    override func insertTab(_ sender: Any?) {
        let indentString = indentStrategy.string(indentLevel: 1)
        if textViewController.shouldChangeText(in: textViewController.rangeForInsertingText, replacementText: indentString) {
            textViewController.replaceText(in: textViewController.rangeForInsertingText, with: indentString)
        }
    }

    /// Copy the selected text.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func copy(_ sender: Any?) {
        let selectedRange = selectedRange()
        if selectedRange.length > 0, let text = textViewController.text(in: selectedRange) {
            NSPasteboard.general.declareTypes([.string], owner: nil)
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// Paste text from the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func paste(_ sender: Any?) {
        let selectedRange = selectedRange()
        if let string = NSPasteboard.general.string(forType: .string) {
            let preparedText = textViewController.prepareTextForInsertion(string)
            textViewController.replaceText(in: selectedRange, with: preparedText)
        }
    }

    /// Cut text  to the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func cut(_ sender: Any?) {
        let selectedRange = selectedRange()
        if selectedRange.length > 0, let text = textViewController.text(in: selectedRange) {
            NSPasteboard.general.setString(text, forType: .string)
            textViewController.replaceText(in: selectedRange, with: "")
        }
    }

    /// Select all text in the text view.
    ///
    /// - Parameter sender: The object calling this method.
    override func selectAll(_ sender: Any?) {
        textViewController.selectedRange = NSRange(location: 0, length: textViewController.stringView.string.length)
    }

    /// Performs the undo operations in the last undo group.
    @objc func undo(_ sender: Any?) {
        if let undoManager = undoManager, undoManager.canUndo {
            undoManager.undo()
        }
    }

    /// Performs the operations in the last group on the redo stack.
    @objc func redo(_ sender: Any?) {
        if let undoManager = undoManager, undoManager.canRedo {
            undoManager.redo()
        }
    }
}
#endif