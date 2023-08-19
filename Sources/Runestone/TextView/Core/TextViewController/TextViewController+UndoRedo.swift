import Foundation

extension TextViewController {
    func addUndoOperationForReplacingText(
        in range: NSRange, 
        with newString: String,
        selectedRangeAfterUndo: NSRange? = nil,
        actionName: String = L10n.Undo.ActionName.typing
    ) {
        let nsNewString = newString as NSString
        let currentText = text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsNewString.length)
        addUndoOperation(
            replacingTextIn: newRange,
            with: currentText,
            selectedRangeAfterUndo: selectedRangeAfterUndo, 
            actionName: actionName
        )
    }

    private func addUndoOperation(
        replacingTextIn range: NSRange,
        with text: String,
        selectedRangeAfterUndo: NSRange? = nil,
        actionName: String = L10n.Undo.ActionName.typing
    ) {
        let oldSelectedRange = selectedRangeAfterUndo ?? selectedRange
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(actionName)
        timedUndoManager.registerUndo(withTarget: self) { textViewController in
            #if os(iOS) || os(xrOS)
            textViewController.textView.inputDelegate?.selectionWillChange(textViewController.textView)
            #endif
            textViewController.addUndoOperationForReplacingText(in: range, with: text)
            textViewController.replaceText(in: range, with: text)
            textViewController.selectedRange = oldSelectedRange
            #if os(iOS) || os(xrOS)
            textViewController.textView.inputDelegate?.selectionDidChange(textViewController.textView)
            #endif
        }
    }
}
