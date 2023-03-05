import Foundation

final class TextStore {
    private let stringView: StringView
    private let lineManager: LineManager

    init(stringView: StringView, lineManager: LineManager) {
        self.stringView = stringView
        self.lineManager = lineManager
    }

    func text(in range: NSRange) -> String? {
        stringView.substring(in: range)
    }

    func replaceText(in range: NSRange, with newString: String) -> TextStoreChange {
        let nsNewString = newString as NSString
        let byteRange = ByteRange(utf16Range: range)
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        stringView.replaceText(in: range, with: newString)
        let lineChangeSet = LineChangeSet()
        let lineChangeSetFromRemovingCharacters = lineManager.removeCharacters(in: range)
        lineChangeSet.formUnion(with: lineChangeSetFromRemovingCharacters)
        let lineChangeSetFromInsertingCharacters = lineManager.insert(nsNewString, at: range.location)
        lineChangeSet.formUnion(with: lineChangeSetFromInsertingCharacters)
        let startLinePosition = lineManager.linePosition(at: range.location)!
        let newEndLinePosition = lineManager.linePosition(at: range.location + nsNewString.length)!
        return TextStoreChange(
            byteRange: byteRange,
            bytesAdded: newString.byteCount,
            oldEndLinePosition: oldEndLinePosition,
            startLinePosition: startLinePosition,
            newEndLinePosition: newEndLinePosition,
            lineChangeSet: lineChangeSet
        )
    }
}
