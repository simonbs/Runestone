import Foundation

struct TextEditor: TextEditing {
    typealias State = MarkedRangeReadable & SelectedRangeWritable

    let state: State
    let stringView: StringView
    let stringTokenizer: StringTokenizing
    let textReplacer: TextReplacing

    func insertText(_ text: String) {
        let insertRange = state.markedRange ?? state.selectedRange.nonNegativeLength
        textReplacer.replaceText(in: insertRange, with: text)
    }

    func replaceText(in range: NSRange, with newText: String) {
        textReplacer.replaceText(in: range, with: newText)
    }

    func deleteBackward() {
        if let deleteBackwardRange {
            textReplacer.replaceText(in: deleteBackwardRange, with: "")
        }
    }

    func deleteForward() {
        if let deleteForwardRange {
            textReplacer.replaceText(in: deleteForwardRange, with: "")
        }
    }

    func deleteWordForward() {
        if let range = range(deleting: .word, inDirection: .forward) {
            textReplacer.replaceText(in: range, with: "")
        }
    }

    func deleteWordBackward() {
        if let range = range(deleting: .word, inDirection: .backward) {
            textReplacer.replaceText(in: range, with: "")
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
        guard state.selectedRange.location < stringView.string.length else {
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
