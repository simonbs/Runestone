import Combine
import Foundation

final class TextEditingUndoManager {
    private let stringView: any StringView
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let undoManager: UndoManager
    private let textReplacer: TextReplacing

    init(
        stringView: any StringView,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        undoManager: UndoManager,
        textReplacer: TextReplacing
    ) {
        self.stringView = stringView
        self.selectedRange = selectedRange
        self.undoManager = undoManager
        self.textReplacer = textReplacer
    }

    func beginUndoGrouping() {
        undoManager.beginUndoGrouping()
    }

    func endUndoGrouping() {
        undoManager.endUndoGrouping()
    }

    func registerUndoOperation(named operationName: String, forReplacingTextIn range: NSRange) {
        let text = stringView.substring(in: range) ?? ""
        undoManager.beginUndoGrouping()
        undoManager.setActionName(L10n.Undo.ActionName.typing)
        undoManager.registerUndo(withTarget: self) { undoManager in
    //            #if os(iOS)
    //            textViewController.textView.inputDelegate?.selectionWillChange(textViewController.textView)
    //            #endif
            undoManager.registerUndoOperation(named: operationName, forReplacingTextIn: range)
            undoManager.textReplacer.replaceText(in: range, with: text)
            undoManager.selectedRange.value = range
    //            #if os(iOS)
    //            textViewController.textView.inputDelegate?.selectionDidChange(textViewController.textView)
    //            #endif
            }
    }

    func removeAllActions() {
        undoManager.removeAllActions()
    }
}
