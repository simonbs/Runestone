import Combine
import Foundation

final class TextEditingUndoManager {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let undoManager: UndoManager
    private let textEditor: TextEditor

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        undoManager: UndoManager,
        textEditor: TextEditor
    ) {
        self.stringView = stringView
        self.selectedRange = selectedRange
        self.undoManager = undoManager
        self.textEditor = textEditor
    }

    func beginUndoGrouping() {
        undoManager.beginUndoGrouping()
    }

    func endUndoGrouping() {
        undoManager.endUndoGrouping()
    }

    func registerUndoOperation(named operationName: String, forReplacingTextIn range: NSRange, selectedRangeAfterUndo: NSRange) {
        let text = stringView.value.substring(in: range) ?? ""
        undoManager.beginUndoGrouping()
        undoManager.setActionName(L10n.Undo.ActionName.typing)
        undoManager.registerUndo(withTarget: self) { undoManager in
    //            #if os(iOS)
    //            textViewController.textView.inputDelegate?.selectionWillChange(textViewController.textView)
    //            #endif
            undoManager.registerUndoOperation(named: operationName, forReplacingTextIn: range, selectedRangeAfterUndo: range)
            undoManager.textEditor.replaceText(in: range, with: text)
            undoManager.selectedRange.value = selectedRangeAfterUndo
    //            #if os(iOS)
    //            textViewController.textView.inputDelegate?.selectionDidChange(textViewController.textView)
    //            #endif
            }
    }

    func removeAllActions() {
        undoManager.removeAllActions()
    }
}
