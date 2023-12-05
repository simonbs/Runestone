import _RunestoneStringUtilities
import Combine
import Foundation

struct _TextEditor<
    StringViewType: StringView, 
    LineManagerType: LineManaging,
    LanguageModeType: InternalLanguageMode
> {
//    let textViewDelegate: ErasedTextViewDelegate
//    let stringView: StringViewType
//    let lineManager: LineManagerType
//    let lineControllerStore: LineControllerStoring
//    let languageMode: LanguageModeType
//    let undoManager: UndoManager
//    let viewport: CurrentValueSubject<CGRect, Never>
//    let lineFragmentLayouter: LineFragmentLayouter

    func replaceText(in range: NSRange, with newString: String) {
//        let lineManagerEditor = LineManagerEditor(lineManager: lineManager)
//        let lineManagerEdit = lineManagerEditor.replaceText(in: range, with: newString) {
//            stringView.replaceText(in: range, with: newString)
//        }
//        let textEdit = TextEdit(replacing: range, with: newString, lineManagerEdit: lineManagerEdit)
//        let languageModeLineChangeSet = languageMode.textDidChange(textEdit)
//        textEdit.lineChangeSet.formUnion(with: languageModeLineChangeSet)
//        for removedLine in textEdit.lineChangeSet.removedLines {
//            lineControllerStore.removeLineController(withID: removedLine.id)
//        }
//        let editedLineIDs = Set(textEdit.lineChangeSet.editedLines.map(\.id))
//        redisplayLines(withIDs: editedLineIDs)
//        if didAddOrRemoveLines {
//            gutterWidthService.invalidateLineNumberWidth()
//        }
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
//        textViewDelegate.textViewDidChange()
//        if !textStoreChange.lineChangeSet.insertedLines.isEmpty || !textStoreChange.lineChangeSet.removedLines.isEmpty {
//            invalidateContentSizeIfNeeded()
//        }
    }
}

private extension _TextEditor {
    func redisplayLines(withIDs lineIDs: Set<UUID>) {
//        for lineID in lineIDs {
//            guard let lineController = LineControllerStore[lineID] else {
//                continue
//            }
//            lineController.invalidateString()
//            lineController.invalidateTypesetting()
//            lineController.invalidateSyntaxHighlighting()
//            guard lineFragmentLayouter.visibleLineIDs.contains(lineID) else {
//                continue
//            }
//            let lineYPosition = lineController.line.yPosition
//            let lineLocalMaxY = lineYPosition + (viewport.value.maxY - lineYPosition)
//            lineController.prepareToDisplayString(to: .yPosition(lineLocalMaxY), syntaxHighlightAsynchronously: false)
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
