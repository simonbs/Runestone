import Foundation

struct CharacterPairTextEditor<StringViewType: StringView>: TextEditing {
    typealias State = CharacterPairsReadable
    & MarkedRangeReadable
    & SelectedRangeWritable

    let state: State
    let stringView: StringViewType
    let textEditor: TextEditing
    let textViewDelegate: ErasedTextViewDelegate

    func insertText(_ text: String) {
        guard state.markedRange == nil else {
            return textEditor.insertText(text)
        }
        guard !handleInsertingCharacterPair(withLeadingComponent: text, in: state.selectedRange) else {
            return
        }
        guard !handleInsertingCharacterPair(withTrailingComponent: text, in: state.selectedRange) else {
            return
        }
        textEditor.insertText(text)
    }

    func replaceText(in range: NSRange, with  newText: String) {
        textEditor.replaceText(in: range, with: newText)
    }

    func deleteBackward() {
        guard state.markedRange == nil else {
            return textEditor.deleteBackward()
        }
        switch state.characterPairTrailingComponentDeletionMode {
        case .immediatelyFollowingLeadingComponent:
            if let range = rangeIncludingTrailingComponent(behind: state.selectedRange) {
                textEditor.replaceText(in: range, with: "")
            } else {
                textEditor.deleteBackward()
            }
        case .disabled:
            textEditor.deleteBackward()
        }
    }

    func deleteForward() {
        textEditor.deleteForward()
    }

    func deleteWordForward() {
        textEditor.deleteWordForward()
    }

    func deleteWordBackward() {
        textEditor.deleteWordBackward()
    }
}

private extension CharacterPairTextEditor {
    private func handleInsertingCharacterPair(withTrailingComponent text: String, in range: NSRange) -> Bool {
        guard let characterPair = state.characterPairs.first(where: { $0.trailing == text }) else {
            return false
        }
        // When typing the trailing component of a character pair, e.g. ) or } and the cursor is in front of
        // that character, the delegate is asked whether the text view should skip inserting that character.
        // If the character is skipped, then the caret is moved after the trailing character component.
        let followingTextRange = NSRange(location: range.location + range.length, length: characterPair.trailing.count)
        let followingText = stringView.substring(in: followingTextRange)
        guard followingText != characterPair.trailing else {
            return false
        }
        guard !textViewDelegate.shouldSkipTrailingComponent(of: characterPair, in: range) else {
            return false
        }
        let newLocation = state.selectedRange.location + characterPair.trailing.count
        state.selectedRange = NSRange(location: newLocation, length: 0)
        return true
    }

    private func handleInsertingCharacterPair(withLeadingComponent text: String, in range: NSRange) -> Bool {
        guard let characterPair = state.characterPairs.first(where: { $0.leading == text }) else {
            return false
        }
        guard textViewDelegate.shouldInsert(characterPair, in: range) else {
            return false
        }
        if state.selectedRange.length == 0 {
            let newText = characterPair.leading + characterPair.trailing
            let newLocation = range.location + characterPair.leading.count
            textEditor.replaceText(in: state.selectedRange, with: newText)
            state.selectedRange = NSRange(location: newLocation, length: 0)
            return true
        } else if let text = stringView.substring(in: state.selectedRange) {
            let newText = characterPair.leading + text + characterPair.trailing
            let newLocation = range.location + characterPair.leading.count
            textEditor.replaceText(in: state.selectedRange, with: newText)
            state.selectedRange = NSRange(location: newLocation, length: range.length)
            return true
        } else {
            return false
        }
    }

    private func rangeIncludingTrailingComponent(behind range: NSRange) -> NSRange? {
        let stringToDelete = stringView.substring(in: range)
        guard let characterPair = state.characterPairs.first(where: { $0.leading == stringToDelete }) else {
            return nil
        }
        let trailingComponentLength = characterPair.trailing.utf16.count
        let trailingComponentRange = NSRange(location: range.upperBound, length: trailingComponentLength)
        guard stringView.substring(in: trailingComponentRange) == characterPair.trailing else {
            return nil
        }
        let deleteLength = trailingComponentRange.upperBound - range.lowerBound
        return NSRange(location: range.lowerBound, length: deleteLength)
    }
}
