import Combine
import Foundation

final class TextEditor {
    private let textViewDelegate: ErasedTextViewDelegate
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let undoManager: UndoManager
    private let viewport: CurrentValueSubject<CGRect, Never>
    private let lineFragmentLayouter: LineFragmentLayouter

    init(
        textViewDelegate: ErasedTextViewDelegate,
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>,
        undoManager: UndoManager,
        viewport: CurrentValueSubject<CGRect, Never>,
        lineFragmentLayouter: LineFragmentLayouter
    ) {
        self.textViewDelegate = textViewDelegate
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.languageMode = languageMode
        self.undoManager = undoManager
        self.viewport = viewport
        self.lineFragmentLayouter = lineFragmentLayouter
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
        let editedLineIDs = Set(textEdit.lineChangeSet.editedLines.map(\.id))
        redisplayLines(withIDs: editedLineIDs)
//        if didAddOrRemoveLines {
//            gutterWidthService.invalidateLineNumberWidth()
//        }
        lineFragmentLayouter.setNeedsLayout()
        lineFragmentLayouter.layoutIfNeeded()
        textViewDelegate.textViewDidChange()
//        if !textStoreChange.lineChangeSet.insertedLines.isEmpty || !textStoreChange.lineChangeSet.removedLines.isEmpty {
//            invalidateContentSizeIfNeeded()
//        }
    }
}

private extension TextEditor {
    func redisplayLines(withIDs lineIDs: Set<LineNodeID>) {
        for lineID in lineIDs {
            guard let lineController = lineControllerStorage[lineID] else {
                continue
            }
            lineController.invalidateString()
            lineController.invalidateTypesetting()
            lineController.invalidateSyntaxHighlighting()
            guard lineFragmentLayouter.visibleLineIDs.contains(lineID) else {
                continue
            }
            let lineYPosition = lineController.line.yPosition
            let lineLocalMaxY = lineYPosition + (viewport.value.maxY - lineYPosition)
            lineController.prepareToDisplayString(to: .yPosition(lineLocalMaxY), syntaxHighlightAsynchronously: false)
        }
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
