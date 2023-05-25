import Combine
import Foundation

struct TextReplacer {
    let stringView: CurrentValueSubject<StringView, Never>
    let selectedRange: CurrentValueSubject<NSRange, Never>
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let textViewDelegate: ErasedTextViewDelegate
    let textEditState: TextEditState
    let textEditor: TextEditor
    let lineEndings: CurrentValueSubject<LineEnding, Never>
    let characterPairService: CharacterPairService
    let replacementTextPreparator: ReplacementTextPreparator
    let undoManager: TextEditingUndoManager

    func replaceText(in range: NSRange, with text: String) {
        let preparedText = preparedText(from: text)
        if textEditState.isRestoringPreviouslyDeletedText {
            // UIKit is inserting text to combine characters, for example to combine two Korean characters into one,
            // and we do not want to interfere with that.
            if textViewDelegate.shouldChangeText(in: range, replacementText: preparedText) {
                justReplaceText(in: range, with: preparedText)
            }
        } else if !characterPairService.handleReplacingText(in: range, with: preparedText) {
            if textViewDelegate.shouldChangeText(in: range, replacementText: preparedText) {
                justReplaceText(in: range, with: preparedText)
            }
        }
    }
}

private extension TextReplacer {
    private func justReplaceText(in range: NSRange, with text: String) {
        undoManager.registerUndoOperation(named: L10n.Undo.ActionName.typing, forReplacingTextIn: range, selectedRangeAfterUndo: range)
        let preparedString = replacementTextPreparator.prepareText(text)
        textEditor.replaceText(in: range, with: preparedString)
        selectedRange.value = NSRange(location: range.location + preparedString.utf16.count, length: 0)
    }

    private func preparedText(from text: String) -> String {
        // Ensure all line endings match our preferred line endings.
        var preparedText = text
        let lineEndingsToReplace: [LineEnding] = [.crlf, .cr, .lf].filter { $0 != lineEndings.value }
        for lineEnding in lineEndingsToReplace {
            preparedText = preparedText.replacingOccurrences(of: lineEnding.symbol, with: lineEndings.value.symbol)
        }
        return preparedText
    }
}
