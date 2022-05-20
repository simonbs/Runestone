import Foundation

extension NSString {
    var byteCount: ByteCount {
        return ByteCount(length * 2)
    }

    func getAllBytes(withEncoding encoding: String.Encoding, usedLength: inout Int) -> UnsafePointer<Int8>? {
        let range = NSRange(location: 0, length: length)
        return getBytes(in: range, encoding: encoding, usedLength: &usedLength)
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
            remaining: nil)
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
        var location = defaultRange.location
        var length = defaultRange.length
        if defaultRange.location > 0 {
            let candidateCRLFRange = NSRange(location: defaultRange.location - 1, length: 2)
            if isCRLFLineEnding(in: candidateCRLFRange) {
                location -= 1
                length += 1
            }
        }
        if defaultRange.upperBound < length - 1 {
            let candidateCRLFRange = NSRange(location: defaultRange.upperBound, length: 2)
            if isCRLFLineEnding(in: candidateCRLFRange) {
                length += 2
            }
        }
        return NSRange(location: location, length: length)
    }
}

private extension NSString {
    private func isCRLFLineEnding(in range: NSRange) -> Bool {
        return substring(with: range) == Symbol.carriageReturnLineFeed
    }
}
