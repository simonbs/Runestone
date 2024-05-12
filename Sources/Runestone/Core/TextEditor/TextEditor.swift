import Foundation

struct TextEditor<StringViewType: StringView>: TextEditing {
    typealias State = MarkedRangeReadable & SelectedRangeWritable

    let state: State
    let stringView: StringViewType
    let stringTokenizer: StringTokenizing
    let textReplacer: TextReplacing

    func insertText(_ text: String) {
        let insertRange = state.markedRange ?? state.selectedRange.nonNegativeLength
        textReplacer.replaceText(in: insertRange, with: text)
        let selectionLocation = insertRange.upperBound + text.utf16.count
        state.selectedRange = NSRange(location: selectionLocation, length: 0)
    }

    func replaceText(in range: NSRange, with newText: String) {
        textReplacer.replaceText(in: range, with: newText)
        let selectionLocation = range.lowerBound + newText.utf16.count
        state.selectedRange = NSRange(location: selectionLocation, length: 0)
    }

    func deleteBackward() {
        if let deleteBackwardRange {
            textReplacer.replaceText(in: deleteBackwardRange, with: "")
            state.selectedRange = NSRange(location: deleteBackwardRange.location, length: 0)
        }
    }

    func deleteForward() {
        if let deleteForwardRange {
            textReplacer.replaceText(in: deleteForwardRange, with: "")
            state.selectedRange = NSRange(location: deleteForwardRange.location, length: 0)
        }
    }

    func deleteWordForward() {
        if let range = range(deleting: .word, inDirection: .forward) {
            textReplacer.replaceText(in: range, with: "")
            state.selectedRange = NSRange(location: range.location, length: 0)
        }
    }

    func deleteWordBackward() {
        if let range = range(deleting: .word, inDirection: .backward) {
            textReplacer.replaceText(in: range, with: "")
            state.selectedRange = NSRange(location: range.location, length: 0)
        }
    }
}

private extension TextEditor {
    private var deleteBackwardRange: NSRange? {
        var range = state.markedRange ?? state.selectedRange
        if range.length == 0 {
            range.location -= 1
            range.length = 1
        }
        guard range.location >= 0 else {
            return nil
        }
        return stringView.string.customRangeOfComposedCharacterSequences(for: range)
    }

    private var deleteForwardRange: NSRange? {
        guard state.selectedRange.location < stringView.length else {
            return nil
        }
        return NSRange(location: state.selectedRange.location, length: 1)
    }

    private func range(
        deleting boundary: TextBoundary,
        inDirection direction: TextDirection
    ) -> NSRange? {
        let sourceLocation = state.selectedRange.location
        guard let destinationLocation = stringTokenizer.location(
            from: sourceLocation,
            toBoundary: boundary,
            inDirection: direction
        ) else {
            return nil
        }
        let lowerBound = min(sourceLocation, destinationLocation)
        let upperBound = max(sourceLocation, destinationLocation)
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }
}
