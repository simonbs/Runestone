import Foundation

package extension NSString {
    var byteCount: ByteCount {
        ByteCount(length * 2)
    }

    func getBytes(in range: NSRange, encoding: String.Encoding, usedLength: inout Int) -> UnsafePointer<Int8>? {
        let byteRange = ByteRange(utf16Range: range)
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: byteRange.length.value)
        let didGetBytes = getBytes(
            buffer,
            maxLength: byteRange.length.value,
            usedLength: &usedLength,
            encoding: encoding.rawValue,
            options: [],
            range: range,
            remaining: nil
        )
        if didGetBytes {
            return UnsafePointer<Int8>(buffer)
        } else {
            return nil
        }
    }

    /// A wrapper around `rangeOfComposedCharacterSequences(for:)` that considers CRLF line endings as composed character sequences.
    func customRangeOfComposedCharacterSequence(at location: Int) -> NSRange {
        let range = NSRange(location: location, length: 0)
        return customRangeOfComposedCharacterSequences(for: range)
    }

    /// A wrapper around `rangeOfComposedCharacterSequences(for:)` that considers CRLF line endings as composed character sequences.
    func customRangeOfComposedCharacterSequences(for range: NSRange) -> NSRange {
        let defaultRange = rangeOfComposedCharacterSequences(for: range)
        let candidateCRLFRange = NSRange(location: defaultRange.location - 1, length: 2)
        guard candidateCRLFRange.location >= 0 && candidateCRLFRange.upperBound <= length else {
            return defaultRange
        }
        guard isCRLFLineEnding(in: candidateCRLFRange) else {
            return defaultRange
        }
        return NSRange(location: defaultRange.location - 1, length: defaultRange.length + 1)
    }
}

private extension NSString {
    private func isCRLFLineEnding(in range: NSRange) -> Bool {
        substring(with: range) == "\r\n"
    }
}
