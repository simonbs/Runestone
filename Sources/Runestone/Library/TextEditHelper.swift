import Foundation
import RunestoneEngine

struct TextEditResult {
    let textChange: TextChange
    let lineChangeSet: LineChangeSet
    var didAddOrRemoveLines: Bool {
        let didAddLines = !lineChangeSet.insertedLines.isEmpty
        let didRemoveLines = !lineChangeSet.removedLines.isEmpty
        return didAddLines || didRemoveLines
    }
}

final class TextEditHelper {
    private let stringView: StringView
    private let lineManager: LineManager
    private let lineEndings: LineEnding

    init(stringView: StringView, lineManager: LineManager, lineEndings: LineEnding) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineEndings = lineEndings
    }

    func replaceText(in range: NSRange, with newString: String) -> TextEditResult {
        precondition(lineManager.stringView === stringView)
        guard let edit = LineEditTransaction.replace(in: lineManager, range: range, with: newString) else {
            preconditionFailure("Invalid text replacement range")
        }
        let textChange = TextChange(byteRange: ByteRange(utf16Range: range),
                                    bytesAdded: newString.byteCount,
                                    oldEndLinePosition: edit.oldEndPosition,
                                    startLinePosition: edit.startPosition,
                                    newEndLinePosition: edit.newEndPosition)
        return TextEditResult(textChange: textChange, lineChangeSet: edit.lineChanges)
    }

    func string(byApplying batchReplaceSet: BatchReplaceSet) -> NSString {
        let sortedReplacements = batchReplaceSet.replacements.sorted { $0.range.lowerBound < $1.range.lowerBound }
        // swiftlint:disable:next force_cast
        let mutableSubstring = stringView.string.mutableCopy() as! NSMutableString
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
