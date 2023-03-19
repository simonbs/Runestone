import Combine
import Foundation

final class CharacterPairService {
    var characterPairs: [CharacterPair] = []
    var trailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    
    private let stringView: CurrentValueSubject<StringView, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let textEditor: TextEditor
    private let handlingAllowedChecker: CharacterPairHandlingAllowedChecker

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        textEditor: TextEditor,
        handlingAllowedChecker: CharacterPairHandlingAllowedChecker
    ) {
        self.stringView = stringView
        self.selectedRange = selectedRange
        self.textEditor = textEditor
        self.handlingAllowedChecker = handlingAllowedChecker
    }

    func handleReplacingText(in range: NSRange, with text: String) -> Bool {
        if let characterPair = characterPair(withTrailingComponent: text), skipInsertingTrailingComponent(of: characterPair, in: range) {
            return true
        } else if let characterPair = characterPair(withLeadingComponent: text), insertLeadingComponent(of: characterPair, in: range) {
            return true
        } else {
            return false
        }
    }
}

private extension CharacterPairService {
    private func characterPair(withLeadingComponent text: String) -> CharacterPair? {
        characterPairs.first(where: { $0.leading == text })
    }

    private func characterPair(withTrailingComponent text: String) -> CharacterPair? {
        characterPairs.first(where: { $0.trailing == text })
    }

    private func insertLeadingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        guard handlingAllowedChecker.shouldInsert(characterPair, in: range) else {
            return false
        }
        if selectedRange.value.length == 0 {
            textEditor.replaceText(in: selectedRange.value, with: characterPair.leading + characterPair.trailing)
            selectedRange.value = NSRange(location: range.location + characterPair.leading.count, length: 0)
            return true
        } else if let text = stringView.value.substring(in: selectedRange.value) {
            textEditor.replaceText(in: selectedRange.value, with: characterPair.leading + text + characterPair.trailing)
            selectedRange.value = NSRange(location: range.location + characterPair.leading.count, length: range.length)
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
        let followingText = stringView.value.substring(in: followingTextRange)
        guard followingText == characterPair.trailing else {
            return false
        }
        guard handlingAllowedChecker.shouldSkipTrailingComponent(of: characterPair, in: range) else {
            return false
        }
        selectedRange.value = NSRange(location: selectedRange.value.location + characterPair.trailing.count, length: 0)
        return true
    }
}
