import Combine
import Foundation

final class BatchReplacer {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let textSetter: TextSetter

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        textSetter: TextSetter
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.textSetter = textSetter
    }

    func replaceText(in batchReplaceSet: BatchReplaceSet) {
        guard !batchReplaceSet.replacements.isEmpty else {
            return
        }
        let oldLinePosition = lineManager.value.linePosition(at: selectedRange.value.location)
        let newString = stringView.value.string.applying(batchReplaceSet)
        textSetter.setText(newString, preservingUndoStack: true)
        // By restoring the selected range using the old line position we can better preserve the old selected language.
        moveCaret(to: oldLinePosition)
    }
}

private extension BatchReplacer {
    private func moveCaret(to linePosition: LinePosition?) {
        guard let linePosition, linePosition.row < lineManager.value.lineCount else {
            selectedRange.value = NSRange(location: stringView.value.string.length, length: 0)
            return
        }
        let line = lineManager.value.line(atRow: linePosition.row)
        let location = line.location + min(linePosition.column, line.data.length)
        selectedRange.value = NSRange(location: location, length: 0)
    }
}

private extension NSString {
    func applying(_ batchReplaceSet: BatchReplaceSet) -> NSString {
        let sortedReplacements = batchReplaceSet.replacements.sorted { $0.range.lowerBound < $1.range.lowerBound }
        // swiftlint:disable:next force_cast
        let mutableSubstring = mutableCopy() as! NSMutableString
        var totalChangeInLength = 0
        var replacedRanges: [NSRange] = []
        for replacement in sortedReplacements where !replacedRanges.contains(where: { $0.overlaps(replacement.range) }) {
            let range = replacement.range
            let adjustedRange = NSRange(location: range.location + totalChangeInLength, length: range.length)
            mutableSubstring.replaceCharacters(in: adjustedRange, with: replacement.text)
            replacedRanges.append(replacement.range)
            totalChangeInLength += replacement.text.utf16.count - adjustedRange.length
        }
        return mutableSubstring
    }
}
