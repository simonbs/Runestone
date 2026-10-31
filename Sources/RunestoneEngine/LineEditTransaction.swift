import Foundation

/// The line-index effects and UTF-16 positions of one text replacement.
public struct LineEditTransactionResult {
    public let lineChanges: LineChangeSet
    public let oldEndPosition: LinePosition
    public let startPosition: LinePosition
    public let newEndPosition: LinePosition
}

/// Applies text and line-index changes in the order required by LineManager.
public enum LineEditTransaction {
    /// Returns nil without changing the document for an invalid UTF-16 range.
    /// The caller must clear folded line ranges before editing and update any
    /// selection, syntax, layout, undo, and folding state after the transaction.
    public static func replace(in manager: LineManager, range: NSRange, with replacement: String) -> LineEditTransactionResult? {
        let text = manager.stringView
        let length = text.string.length
        guard range.location >= 0, range.length >= 0, range.location <= length,
              range.length <= length - range.location,
              let oldEnd = manager.linePosition(at: range.location + range.length) else { return nil }
        let inserted = replacement as NSString
        text.replaceText(in: range, with: replacement)
        let changes = manager.removeCharacters(in: range)
        changes.union(with: manager.insert(inserted, at: range.location))
        // After a valid edit, the start and inserted end belong to the updated index.
        let start = manager.linePosition(at: range.location)!
        let newEnd = manager.linePosition(at: range.location + inserted.length)!
        return LineEditTransactionResult(lineChanges: changes, oldEndPosition: oldEnd,
                                         startPosition: start, newEndPosition: newEnd)
    }
}
