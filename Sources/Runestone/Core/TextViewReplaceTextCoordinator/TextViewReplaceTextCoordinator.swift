import Combine
import Foundation

final class TextViewReplaceTextCoordinator {
    private let textStore: TextStore
    private let selectedRangeService: SelectedRangeService
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let undoManager: UndoManagable
    private let textInputDelegate: TextInputDelegate

    init(
        textStore: TextStore,
        selectedRangeService: SelectedRangeService,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>,
        undoManager: UndoManagable,
        textInputDelegate: TextInputDelegate
    ) {
        self.textStore = textStore
        self.selectedRangeService = selectedRangeService
        self.languageMode = languageMode
        self.undoManager = undoManager
        self.textInputDelegate = textInputDelegate
    }

    func replaceText(in range: NSRange, with newString: String) {
        addUndoOperation(replacing: range, with: newString)
        let newRange = NSRange(location: range.location, length: newString.utf16.count)
        selectedRangeService.moveCaret(to: newRange.upperBound)
        let textStoreChange = textStore.replaceText(in: range, with: newString)
        let languageModeLineChangeSet = languageMode.value.textDidChange(textStoreChange)
        textStoreChange.lineChangeSet.formUnion(with: languageModeLineChangeSet)
        applyLineChanges(textStoreChange.lineChangeSet)
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
//        let updatedTextEditResult = TextEditResult(textChange: result.textChange, lineChangeSet: result.lineChangeSet)
//        textDidChange()
//        if updatedTextEditResult.didAddOrRemoveLines {
//            invalidateContentSizeIfNeeded()
//        }
    }
}

private extension TextViewReplaceTextCoordinator {
    private func addUndoOperation(replacing range: NSRange, with newString: String) {
        let currentText = textStore.text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: newString.utf16.count)
        let oldSelectedRange = selectedRangeService.selectedRange
        undoManager.beginUndoGrouping()
        undoManager.setActionName(L10n.Undo.ActionName.typing)
        undoManager.registerUndo(withTarget: self) { coordinator in
            coordinator.textInputDelegate.selectionWillChange()
            coordinator.replaceText(in: newRange, with: currentText)
            coordinator.selectedRangeService.selectRange(oldSelectedRange)
            coordinator.textInputDelegate.selectionDidChange()
        }
    }

    private func applyLineChanges(_ lineChangeSet: LineChangeSet) {
//        let didAddOrRemoveLines = !lineChangeSet.insertedLines.isEmpty || !lineChangeSet.removedLines.isEmpty
//        if didAddOrRemoveLines {
//            contentSizeService.invalidateContentSize()
//            for removedLine in lineChangeSet.removedLines {
//                lineControllerStorage.removeLineController(withID: removedLine.id)
//                contentSizeService.removeLine(withID: removedLine.id)
//            }
//        }
//        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
//        redisplayLines(withIDs: editedLineIDs)
//        if didAddOrRemoveLines {
//            gutterWidthService.invalidateLineNumberWidth()
//        }
    }
}
