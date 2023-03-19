import Combine
import Foundation

final class TextReplacer {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let markedRange: CurrentValueSubject<NSRange?, Never>
    private let textEditAllowedChecker: TextEditAllowedChecker
    private let textEditor: TextEditor
    private let characterPairService: CharacterPairService
    private let replacementTextPreparator: ReplacementTextPreparator
    private let undoManager: TextEditingUndoManager

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        markedRange: CurrentValueSubject<NSRange?, Never>,
        textEditAllowedChecker: TextEditAllowedChecker,
        textEditor: TextEditor,
        characterPairService: CharacterPairService,
        replacementTextPreparator: ReplacementTextPreparator,
        undoManager: TextEditingUndoManager
    ) {
        self.stringView = stringView
        self.selectedRange = selectedRange
        self.markedRange = markedRange
        self.textEditAllowedChecker = textEditAllowedChecker
        self.textEditor = textEditor
        self.characterPairService = characterPairService
        self.replacementTextPreparator = replacementTextPreparator
        self.undoManager = undoManager
    }

    func replaceText(in range: NSRange, with text: String) {
        if skipInsertComponentCheck {
            // UIKit is inserting text to combine characters, for example to combine two Korean characters into one,
            // and we do not want to interfere with that.
            if textEditAllowedChecker.shouldChangeText(in: range, replacementText: text) {
                justReplaceText(in: range, with: text)
            }
        } else if !characterPairService.handleReplacingText(in: range, with: text) {
            if textEditAllowedChecker.shouldChangeText(in: range, replacementText: text) {
                justReplaceText(in: range, with: text)
            }
        }
    }
}

private extension TextReplacer {
    private var skipInsertComponentCheck: Bool {
        #if os(iOS)
        return textView.isRestoringPreviouslyDeletedText
        #else
        return false
        #endif
    }

    private func justReplaceText(in range: NSRange, with text: String) {
        undoManager.registerUndoOperation(named: L10n.Undo.ActionName.typing, forReplacingTextIn: range, selectedRangeAfterUndo: range)
        let preparedString = replacementTextPreparator.prepareText(text)
        selectedRange.value = NSRange(location: range.location + preparedString.utf16.count, length: 0)
        textEditor.replaceText(in: range, with: preparedString)
    }
}
