import Combine
import Foundation

final class TextShifter {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let indentStrategy: CurrentValueSubject<IndentStrategy, Never>
    private let textEditor: TextEditor

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        indentStrategy: CurrentValueSubject<IndentStrategy, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        textEditor: TextEditor
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.indentStrategy = indentStrategy
        self.selectedRange = selectedRange
        self.textEditor = textEditor
    }

    func shiftLeft(in selectedRange: NSRange) {
        let lines = lineManager.value.lines(in: selectedRange)
        let originalRange = range(surrounding: lines)
        var newSelectedRange = selectedRange
        var replacementString: String?
        let indentString = indentStrategy.value.string(indentLevel: 1)
        let utf8IndentLength = indentString.count
        let utf16IndentLength = indentString.utf16.count
        for (lineIndex, line) in lines.enumerated() {
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            let lineString = stringView.value.substring(in: lineRange) ?? ""
            guard lineString.hasPrefix(indentString) else {
                replacementString = (replacementString ?? "") + lineString
                continue
            }
            let startIndex = lineString.index(lineString.startIndex, offsetBy: utf8IndentLength)
            let endIndex = lineString.endIndex
            replacementString = (replacementString ?? "") + lineString[startIndex ..< endIndex]
            if lineIndex == 0 {
                // We don't want the selection to move to the previous line when we can't shift left anymore.
                // Therefore we keep it to the minimum location, which is the location the line starts on.
                // If we try to exceed that, we need to adjust the length of the selected range.
                let preferredLocation = newSelectedRange.location - utf16IndentLength
                let newLocation = max(preferredLocation, originalRange.location)
                newSelectedRange.location = newLocation
                if newLocation > preferredLocation {
                    let preferredLength = newSelectedRange.length - (newLocation - preferredLocation)
                    newSelectedRange.length = max(preferredLength, 0)
                }
            } else {
                newSelectedRange.length -= utf16IndentLength
            }
        }
        if let replacementString = replacementString {
            textEditor.replaceText(in: originalRange, with: replacementString)
            self.selectedRange.value = newSelectedRange
        }
    }

    func shiftRight(in selectedRange: NSRange) {
        let lines = lineManager.value.lines(in: selectedRange)
        let originalRange = range(surrounding: lines)
        var newSelectedRange = selectedRange
        var replacementString: String?
        let indentString = indentStrategy.value.string(indentLevel: 1)
        let indentLength = indentString.utf16.count
        for (lineIndex, line) in lines.enumerated() {
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            let lineString = stringView.value.substring(in: lineRange) ?? ""
            replacementString = (replacementString ?? "") + indentString + lineString
            if lineIndex == 0 {
                newSelectedRange.location += indentLength
            } else {
                newSelectedRange.length += indentLength
            }
        }
        if let replacementString = replacementString {
            textEditor.replaceText(in: originalRange, with: replacementString)
            self.selectedRange.value = newSelectedRange
        }
    }
}

private extension TextShifter {
    private func range(surrounding lines: [LineNode]) -> NSRange {
        let firstLine = lines[0]
        let lastLine = lines[lines.count - 1]
        let location = firstLine.location
        let length = (lastLine.location - location) + lastLine.data.totalLength
        return NSRange(location: location, length: length)
    }
}
