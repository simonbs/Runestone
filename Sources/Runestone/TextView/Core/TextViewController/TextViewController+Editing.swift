import Foundation

extension TextViewController {
//    func text(in range: NSRange) -> String? {
//        stringView.value.substring(in: range.nonNegativeLength)
//    }
//
//    func replaceText(in batchReplaceSet: BatchReplaceSet) {
//        guard !batchReplaceSet.replacements.isEmpty else {
//            return
//        }
//        let oldLinePosition = lineManager.value.linePosition(at: selectedRange.value.location)
//        let newString = stringView.value.string.applying(batchReplaceSet)
//        setStringWithUndoAction(newString)
//        if let oldLinePosition = oldLinePosition {
//            // By restoring the selected range using the old line position we can better preserve the old selected language.
//            moveCaret(to: oldLinePosition)
//        }
//    }

//    func rangeForDeletingText(in range: NSRange) -> NSRange {
//        var resultingRange = range
//        if range.length == 1, let indentRange = indentService.indentRangeInFrontOfLocation(range.upperBound) {
//            resultingRange = indentRange
//        } else {
//            resultingRange = stringView.value.string.customRangeOfComposedCharacterSequences(for: range)
//        }
//        // If deleting the leading component of a character pair we may also expand the range to delete the trailing component.
//        if characterPairTrailingComponentDeletionMode == .immediatelyFollowingLeadingComponent
//            && maximumLeadingCharacterPairComponentLength > 0
//            && resultingRange.length <= maximumLeadingCharacterPairComponentLength {
//            let stringToDelete = stringView.value.substring(in: resultingRange)
//            if let characterPair = characterPairs.first(where: { $0.leading == stringToDelete }) {
//                let trailingComponentLength = characterPair.trailing.utf16.count
//                let trailingComponentRange = NSRange(location: resultingRange.upperBound, length: trailingComponentLength)
//                if stringView.value.substring(in: trailingComponentRange) == characterPair.trailing {
//                    let deleteRange = trailingComponentRange.upperBound - resultingRange.lowerBound
//                    resultingRange = NSRange(location: resultingRange.lowerBound, length: deleteRange)
//                }
//            }
//        }
//        return resultingRange
//    }
}

private extension TextViewController {
    

    private func setStringWithUndoAction(_ newString: NSString) {
//        guard newString != stringView.value.string else {
//            return
//        }
//        guard let oldString = stringView.value.string.copy() as? NSString else {
//            return
//        }
//        timedUndoManager.endUndoGrouping()
//        let oldSelectedRange = selectedRange.value
//        preserveUndoStackWhenSettingString = true
//        text = newString as String
//        preserveUndoStackWhenSettingString = false
//        timedUndoManager.beginUndoGrouping()
//        timedUndoManager.setActionName(L10n.Undo.ActionName.replaceAll)
//        timedUndoManager.registerUndo(withTarget: self) { textInputView in
//            textInputView.setStringWithUndoAction(oldString)
//        }
//        timedUndoManager.endUndoGrouping()
//        textDidChange()
//        selectedRange.value = oldSelectedRange.capped(to: stringView.value.string.length)
    }

//    private func textDidChange() {
//        if isAutomaticScrollEnabled, selectedRange.value.length == 0 {
//            scrollLocationToVisible(selectedRange.value.location)
//        }
//        delegate?.textViewControllerDidChangeText(self)
//    }

    private func moveCaret(to linePosition: LinePosition) {
        let cappedRow = max(linePosition.row, lineManager.value.lineCount - 1)
        let line = lineManager.value.line(atRow: cappedRow)
        let location = line.location + min(linePosition.column, line.data.length)
        selectedRange.value = NSRange(location: location, length: 0)
    }
}
