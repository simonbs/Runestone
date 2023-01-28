import Foundation

extension TextViewController {
    func text(in range: NSRange) -> String? {
        stringView.substring(in: range.nonNegativeLength)
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
        let textEditHelper = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: lineEndings)
        let textEditResult = textEditHelper.replaceText(in: range, with: newString)
        let textChange = textEditResult.textChange
        let lineChangeSet = textEditResult.lineChangeSet
        let languageModeLineChangeSet = languageMode.textDidChange(textChange)
        lineChangeSet.union(with: languageModeLineChangeSet)
        applyLineChangesToLayoutManager(lineChangeSet)
        let updatedTextEditResult = TextEditResult(textChange: textChange, lineChangeSet: lineChangeSet)
        if isAutomaticScrollEnabled, let newRange = selectedRange, newRange.length == 0 {
            scrollLocationToVisible(newRange.location)
        }
        textView.editorDelegate?.textViewDidChange(textView)
        if updatedTextEditResult.didAddOrRemoveLines {
            invalidateContentSizeIfNeeded()
        }
    }

    func rangeForDeletingText(in range: NSRange) -> NSRange {
        var resultingRange = range
        if range.length == 1, let indentRange = indentController.indentRangeInFrontOfLocation(range.upperBound) {
            resultingRange = indentRange
        } else {
            resultingRange = stringView.string.customRangeOfComposedCharacterSequences(for: range)
        }
        // If deleting the leading component of a character pair we may also expand the range to delete the trailing component.
        if characterPairTrailingComponentDeletionMode == .immediatelyFollowingLeadingComponent
            && maximumLeadingCharacterPairComponentLength > 0
            && resultingRange.length <= maximumLeadingCharacterPairComponentLength {
            let stringToDelete = stringView.substring(in: resultingRange)
            if let characterPair = characterPairs.first(where: { $0.leading == stringToDelete }) {
                let trailingComponentLength = characterPair.trailing.utf16.count
                let trailingComponentRange = NSRange(location: resultingRange.upperBound, length: trailingComponentLength)
                if stringView.substring(in: trailingComponentRange) == characterPair.trailing {
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
            insertText(characterPair.leading + characterPair.trailing)
            self.selectedRange = NSRange(location: range.location + characterPair.leading.count, length: 0)
            return true
        } else if let text = text(in: selectedRange) {
            let modifiedText = characterPair.leading + text + characterPair.trailing
            let indexedRange = IndexedRange(selectedRange)
            replace(indexedRange, withText: modifiedText)
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
}
