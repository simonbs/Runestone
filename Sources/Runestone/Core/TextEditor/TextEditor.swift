import Combine
import Foundation

final class TextEditor {
    let didEdit = PassthroughSubject<Void, Never>()

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let lineControllerStorage: LineControllerStorage
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let undoManager: UndoManager

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineControllerStorage: LineControllerStorage,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>,
        undoManager: UndoManager
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.lineControllerStorage = lineControllerStorage
        self.languageMode = languageMode
        self.undoManager = undoManager
    }

    func replaceText(in range: NSRange, with newString: String) {
        let lineManagerEditor = LineManagerEditor(lineManager: lineManager.value)
        let lineManagerEdit = lineManagerEditor.replaceText(in: range, with: newString) {
            stringView.value.replaceText(in: range, with: newString)
        }
        let textEdit = TextEdit(replacing: range, with: newString, lineManagerEdit: lineManagerEdit)
        let languageModeLineChangeSet = languageMode.value.textDidChange(textEdit)
        textEdit.lineChangeSet.formUnion(with: languageModeLineChangeSet)
        for removedLine in textEdit.lineChangeSet.removedLines {
            lineControllerStorage.removeLineController(withID: removedLine.id)
        }
        didEdit.send(())
//        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
//        redisplayLines(withIDs: editedLineIDs)
//        if didAddOrRemoveLines {
//            gutterWidthService.invalidateLineNumberWidth()
//        }
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
//        textDidChange()
//        if !textStoreChange.lineChangeSet.insertedLines.isEmpty || !textStoreChange.lineChangeSet.removedLines.isEmpty {
//            invalidateContentSizeIfNeeded()
//        }
    }
}

private extension TextEdit {
    init(replacing range: NSRange, with newString: String, lineManagerEdit: LineManagerEdit) {
        self.init(
            byteRange: ByteRange(utf16Range: range),
            bytesAdded: newString.byteCount,
            oldEndLinePosition: lineManagerEdit.oldEndLinePosition,
            startLinePosition: lineManagerEdit.startLinePosition,
            newEndLinePosition: lineManagerEdit.newEndLinePosition,
            lineChangeSet: lineManagerEdit.lineChangeSet
        )
    }
}
