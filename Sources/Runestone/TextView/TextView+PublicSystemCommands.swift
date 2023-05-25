#if os(macOS)
import AppKit

public extension TextView {
    /// Deletes a character from the displayed text.
    override func deleteForward(_ sender: Any?) {
        textDeleter.deleteForward()
    }

    /// Deletes a character from the displayed text.
    override func deleteBackward(_ sender: Any?) {
        textDeleter.deleteBackward()
    }

    /// Inserts a newline character.
    override func insertNewline(_ sender: Any?) {
        textInserter.insertNewLine()
    }

    /// Inserts a tab character.
    override func insertTab(_ sender: Any?) {
        textInserter.insertTab()
    }

    /// Copy the selected text.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func copy(_ sender: Any?) {
        let selectedRange = selectedRange()
        if selectedRange.length > 0, let text = stringView.value.substring(in: selectedRange) {
            NSPasteboard.general.declareTypes([.string], owner: nil)
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// Paste text from the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func paste(_ sender: Any?) {
//        let selectedRange = selectedRange()
//        if let string = NSPasteboard.general.string(forType: .string) {
//            let preparedText = prepareTextForInsertion(string)
//            textInputHandler.replaceText(in: selectedRange, with: preparedText)
//        }
    }

    /// Cut text  to the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func cut(_ sender: Any?) {
//        let selectedRange = selectedRange()
//        if selectedRange.length > 0, let text = stringView.value.substring(in: selectedRange) {
//            NSPasteboard.general.setString(text, forType: .string)
//            textEditor.replaceText(in: selectedRange, with: "")
//        }
    }

    /// Select all text in the text view.
    ///
    /// - Parameter sender: The object calling this method.
    override func selectAll(_ sender: Any?) {
        let stringLength = stringView.value.string.length
        selectedRangeSubject.value = NSRange(location: 0, length: stringLength)
    }

    /// Performs the undo operations in the last undo group.
    @objc func undo(_ sender: Any?) {
        if let undoManager, undoManager.canUndo {
            undoManager.undo()
        }
    }

    /// Performs the operations in the last group on the redo stack.
    @objc func redo(_ sender: Any?) {
        if let undoManager, undoManager.canRedo {
            undoManager.redo()
        }
    }

    /// Delete the word in front of the insertion point.
    override func deleteWordForward(_ sender: Any?) {
        textDeleter.deleteWordForward()
    }

    /// Delete the word behind the insertion point.
    override func deleteWordBackward(_ sender: Any?) {
        textDeleter.deleteWordBackward()
    }
}
#endif
