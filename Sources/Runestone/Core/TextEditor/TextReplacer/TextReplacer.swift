import Combine
import Foundation

struct TextReplacer {
    let stringView: CurrentValueSubject<StringView, Never>
    let selectedRange: CurrentValueSubject<NSRange, Never>
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let textViewDelegate: ErasedTextViewDelegate
    let textEditor: TextEditor
    let characterPairService: CharacterPairService
    let replacementTextPreparator: ReplacementTextPreparator
    let undoManager: TextEditingUndoManager

    func replaceText(in range: NSRange, with text: String) {
        if skipInsertComponentCheck {
            // UIKit is inserting text to combine characters, for example to combine two Korean characters into one,
            // and we do not want to interfere with that.
            if textViewDelegate.shouldChangeText(in: range, replacementText: text) {
                justReplaceText(in: range, with: text)
            }
        } else if !characterPairService.handleReplacingText(in: range, with: text) {
            if textViewDelegate.shouldChangeText(in: range, replacementText: text) {
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
