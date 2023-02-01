import Foundation

extension TextViewController {
    func addUndoOperation(
        replacing range: NSRange,
        withText text: String,
        selectedRangeAfterUndo: NSRange? = nil,
        actionName: String = L10n.Undo.ActionName.typing
    ) {
        let oldSelectedRange = selectedRangeAfterUndo ?? selectedRange
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(actionName)
        timedUndoManager.registerUndo(withTarget: self) { textViewController in
            #if os(iOS)
            textViewController.textView.inputDelegate?.selectionWillChange(textViewController.textView)
            #endif
            textViewController.replaceText(in: range, with: text)
            textViewController.selectedRange = oldSelectedRange
            #if os(iOS)
            textViewController.textView.inputDelegate?.selectionDidChange(textViewController.textView)
            #endif
        }
    }
}
