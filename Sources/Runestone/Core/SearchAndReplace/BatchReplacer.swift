import Combine
import Foundation

struct BatchReplacer<LineManagerType: LineManaging> {
    typealias State = SelectedRangeWritable

    let state: State
    let stringView: StringView
    let lineManager: LineManagerType
    let textSetter: TextSetting

    func replaceText(in batchReplaceSet: BatchReplaceSet) {
        guard !batchReplaceSet.replacements.isEmpty else {
            return
        }
        let oldLinePosition = lineManager.linePosition(at: state.selectedRange.location)
        let newString = stringView.string.applying(batchReplaceSet) as String
        textSetter.setText(newString, preservingUndoStack: true)
        // By restoring the selected range using the old line position
        // we can better preserve the old selected language.
        moveCaret(to: oldLinePosition)
    }
}

private extension BatchReplacer {
    private func moveCaret(to linePosition: LinePosition?) {
        guard let linePosition, linePosition.row < lineManager.lineCount else {
            state.selectedRange = NSRange(location: stringView.length, length: 0)
            return
        }
        let line = lineManager[linePosition.row]
        let location = line.location + min(linePosition.column, line.length)
        state.selectedRange = NSRange(location: location, length: 0)
    }
}

private extension NSString {
    func applying(_ batchReplaceSet: BatchReplaceSet) -> NSString {
        let sortedReplacements = batchReplaceSet.replacements.sorted { $0.range.lowerBound < $1.range.lowerBound }
        // swiftlint:disable:next force_cast
        let mutableSubstring = mutableCopy() as! NSMutableString
        var totalChangeInLength = 0
        var replacedRanges: [NSRange] = []
        for replacement in sortedReplacements where !replacedRanges.contains(where: {
            $0.overlaps(replacement.range)
        }) {
            let range = replacement.range
            let adjustedRange = NSRange(location: range.location + totalChangeInLength, length: range.length)
            mutableSubstring.replaceCharacters(in: adjustedRange, with: replacement.text)
            replacedRanges.append(replacement.range)
            totalChangeInLength += replacement.text.utf16.count - adjustedRange.length
        }
        return mutableSubstring
    }
}
