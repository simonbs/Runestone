import Foundation
import Symbol

public extension NSString {
    /// A wrapper around `rangeOfComposedCharacterSequences(for:)` that considers CRLF line endings as composed character sequences.
    func customRangeOfComposedCharacterSequence(at location: Int) -> NSRange {
        let range = NSRange(location: location, length: 0)
        return customRangeOfComposedCharacterSequences(for: range)
    }

    /// A wrapper around `rangeOfComposedCharacterSequences(for:)` that considers CRLF line endings as composed character sequences.
    func customRangeOfComposedCharacterSequences(for range: NSRange) -> NSRange {
        let defaultRange = rangeOfComposedCharacterSequences(for: range)
        let candidateCRLFRange = NSRange(location: defaultRange.location - 1, length: 2)
        if candidateCRLFRange.location >= 0 && candidateCRLFRange.upperBound <= length && isCRLFLineEnding(in: candidateCRLFRange) {
            return NSRange(location: defaultRange.location - 1, length: defaultRange.length + 1)
        } else {
            return defaultRange
        }
    }
}

private extension NSString {
    private func isCRLFLineEnding(in range: NSRange) -> Bool {
        substring(with: range) == Symbol.carriageReturnLineFeed
    }
}
