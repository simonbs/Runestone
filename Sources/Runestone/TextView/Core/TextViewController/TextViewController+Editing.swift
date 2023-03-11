import Foundation

extension TextViewController {
    var rangeForInsertingText: NSRange {
        // If there is no marked range or selected range then we fallback to appending text to the end of our string.
        markedRange ?? selectedRange?.nonNegativeLength ?? NSRange(location: stringView.value.string.length, length: 0)
    }

    func text(in range: NSRange) -> String? {
        stringView.value.substring(in: range.nonNegativeLength)
    }

    func replaceText(
        in range: NSRange,
        with newString: String,
        selectedRangeAfterUndo: NSRange? = nil,
        undoActionName: String = L10n.Undo.ActionName.typing
    ) {
        let nsNewString = newString as NSString
        let currentText = text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsNewString.length)
        addUndoOperation(replacing: newRange, withText: currentText, selectedRangeAfterUndo: selectedRangeAfterUndo, actionName: undoActionName)
        selectedRange = NSRange(location: newRange.upperBound, length: 0)
        let textStore = TextStore(stringView: stringView.value, lineManager: lineManager.value)
        let textStoreChange = textStore.replaceText(in: range, with: newString)
        let languageModeLineChangeSet = languageMode.value.textDidChange(textStoreChange)
        textStoreChange.lineChangeSet.formUnion(with: languageModeLineChangeSet)
        applyLineChanges(textStoreChange.lineChangeSet)
        lineFragmentLayouter.setNeedsLayout()
        lineFragmentLayouter.layoutIfNeeded()
        textDidChange()
        if !textStoreChange.lineChangeSet.insertedLines.isEmpty || !textStoreChange.lineChangeSet.removedLines.isEmpty {
//            invalidateContentSizeIfNeeded()
        }
    }

    func replaceText(in batchReplaceSet: BatchReplaceSet) {
        guard !batchReplaceSet.replacements.isEmpty else {
            return
        }
        var oldLinePosition: LinePosition?
        if let oldSelectedRange = selectedRange {
            oldLinePosition = lineManager.value.linePosition(at: oldSelectedRange.location)
        }
        let newString = stringView.value.string.applying(batchReplaceSet)
        setStringWithUndoAction(newString)
        if let oldLinePosition = oldLinePosition {
            // By restoring the selected range using the old line position we can better preserve the old selected language.
            moveCaret(to: oldLinePosition)
        }
    }

    func rangeForDeletingText(in range: NSRange) -> NSRange {
        var resultingRange = range
        if range.length == 1, let indentRange = indentController.indentRangeInFrontOfLocation(range.upperBound) {
            resultingRange = indentRange
        } else {
            resultingRange = stringView.value.string.customRangeOfComposedCharacterSequences(for: range)
        }
        // If deleting the leading component of a character pair we may also expand the range to delete the trailing component.
        if characterPairTrailingComponentDeletionMode == .immediatelyFollowingLeadingComponent
            && maximumLeadingCharacterPairComponentLength > 0
            && resultingRange.length <= maximumLeadingCharacterPairComponentLength {
            let stringToDelete = stringView.value.substring(in: resultingRange)
            if let characterPair = characterPairs.first(where: { $0.leading == stringToDelete }) {
                let trailingComponentLength = characterPair.trailing.utf16.count
                let trailingComponentRange = NSRange(location: resultingRange.upperBound, length: trailingComponentLength)
                if stringView.value.substring(in: trailingComponentRange) == characterPair.trailing {
                    let deleteRange = trailingComponentRange.upperBound - resultingRange.lowerBound
                    resultingRange = NSRange(location: resultingRange.lowerBound, length: deleteRange)
                }
            }
        }
        return resultingRange
    }

    func prepareTextForInsertion(_ text: String) -> String {
        // Ensure all line endings match our preferred line endings.
        var preparedText = text
        let lineEndingsToReplace: [LineEnding] = [.crlf, .cr, .lf].filter { $0 != lineEndings }
        for lineEnding in lineEndingsToReplace {
            preparedText = preparedText.replacingOccurrences(of: lineEnding.symbol, with: lineEndings.symbol)
        }
        return preparedText
    }

    func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        if skipInsertComponentCheck {
            // UIKit is inserting text to combine characters, for example to combine two Korean characters into one, and we do not want to interfere with that.
            return textView.editorDelegate?.textView(textView, shouldChangeTextIn: range, replacementText: text) ?? true
        } else if let characterPair = characterPairs.first(where: { $0.trailing == text }),
                  skipInsertingTrailingComponent(of: characterPair, in: range) {
            return false
        } else if let characterPair = characterPairs.first(where: { $0.leading == text }), insertLeadingComponent(of: characterPair, in: range) {
            return false
        } else {
            return delegateAllowsChangeText(in: range, withReplacementText: text)
        }
    }
}

private extension TextViewController {
    private var skipInsertComponentCheck: Bool {
        #if os(iOS)
        return textView.isRestoringPreviouslyDeletedText
        #else
        return false
        #endif
    }

    private func delegateAllowsChangeText(in range: NSRange, withReplacementText replacementText: String) -> Bool {
        textView.editorDelegate?.textView(textView, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    private func insertLeadingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        let shouldInsertCharacterPair = textView.editorDelegate?.textView(textView, shouldInsert: characterPair, in: range) ?? true
        guard shouldInsertCharacterPair else {
            return false
        }
        guard let selectedRange = selectedRange else {
            return false
        }
        if selectedRange.length == 0 {
            replaceText(in: selectedRange, with: characterPair.leading + characterPair.trailing)
            self.selectedRange = NSRange(location: range.location + characterPair.leading.count, length: 0)
            return true
        } else if let text = text(in: selectedRange) {
            let modifiedText = characterPair.leading + text + characterPair.trailing
            replaceText(in: selectedRange, with: modifiedText)
            self.selectedRange = NSRange(location: range.location + characterPair.leading.count, length: range.length)
            return true
        } else {
            return false
        }
    }

    private func skipInsertingTrailingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        // When typing the trailing component of a character pair, e.g. ) or } and the cursor is just in front of that character,
        // the delegate is asked whether the text view should skip inserting that character. If the character is skipped,
        // then the caret is moved after the trailing character component.
        let followingTextRange = NSRange(location: range.location + range.length, length: characterPair.trailing.count)
        let followingText = text(in: followingTextRange)
        guard followingText == characterPair.trailing else {
            return false
        }
        let shouldSkip = textView.editorDelegate?.textView(textView, shouldSkipTrailingComponentOf: characterPair, in: range) ?? true
        guard shouldSkip else {
            return false
        }
        if let selectedRange = selectedRange {
            let offset = characterPair.trailing.count
            self.selectedRange = NSRange(location: selectedRange.location + offset, length: 0)
        }
        return true
    }

    private func setStringWithUndoAction(_ newString: NSString) {
        guard newString != stringView.value.string else {
            return
        }
        guard let oldString = stringView.value.string.copy() as? NSString else {
            return
        }
        timedUndoManager.endUndoGrouping()
        let oldSelectedRange = selectedRange
        preserveUndoStackWhenSettingString = true
        text = newString as String
        preserveUndoStackWhenSettingString = false
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(L10n.Undo.ActionName.replaceAll)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            textInputView.setStringWithUndoAction(oldString)
        }
        timedUndoManager.endUndoGrouping()
        textDidChange()
        if let oldSelectedRange = oldSelectedRange {
            selectedRange = oldSelectedRange.capped(to: stringView.value.string.length)
        }
    }

    private func textDidChange() {
        if isAutomaticScrollEnabled, let newRange = selectedRange, newRange.length == 0 {
            scrollLocationToVisible(newRange.location)
        }
        delegate?.textViewControllerDidChangeText(self)
    }

    private func moveCaret(to linePosition: LinePosition) {
        if linePosition.row < lineManager.value.lineCount {
            let line = lineManager.value.line(atRow: linePosition.row)
            let location = line.location + min(linePosition.column, line.data.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = nil
        }
    }

    private func applyLineChanges(_ lineChangeSet: LineChangeSet) {
        let didAddOrRemoveLines = !lineChangeSet.insertedLines.isEmpty || !lineChangeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
//            contentSizeService.invalidateContentSize()
            for removedLine in lineChangeSet.removedLines {
                lineControllerStorage.removeLineController(withID: removedLine.id)
//                contentSizeService.removeLine(withID: removedLine.id)
            }
        }
        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
        redisplayLines(withIDs: editedLineIDs)
//        if didAddOrRemoveLines {
//            gutterWidthService.invalidateLineNumberWidth()
//        }
    }
}
