import Foundation

extension NSRange {
    /// Creates an NSRange from a `ByteRange`.
    /// - Parameter byteRange: `ByteRange` to convert to NSRange.
    init(_ byteRange: ByteRange) {
        let location = byteRange.location.value / 2
        let length = byteRange.length.value / 2
        self.init(location: location, length: length)
    }

    /// Takes a range in the global string range and returns it as a range capped and local to the string in the line.
    /// Returns nil if the line does not contain the range.
    /// - Parameters:
    ///   - globalRange: Range in the global string.
    ///   - line: Line which range should be capped by and local to.
    init?(globalRange: NSRange, cappedLocalTo line: DocumentLineNode) {
        self.init(globalRange: globalRange, cappedTo: line, localToLine: true)
    }

    /// Takes a range in the global string range and returns it as a range capped to the string in the line.
    /// The returned range is still relative to the global string. Returns nil if the line does not contain the range.
    /// - Parameters:
    ///   - globalRange: Range in the global string.
    ///   - line: Line range should be capped by.
    init?(globalRange: NSRange, cappedTo line: DocumentLineNode) {
        self.init(globalRange: globalRange, cappedTo: line, localToLine: false)
    }

    private init?(globalRange: NSRange, cappedTo line: DocumentLineNode, localToLine: Bool) {
        let lineLocation = line.location
        let lineLength = line.data.totalLength
        let globalLineRange = NSRange(location: lineLocation, length: lineLength)
        guard globalRange.upperBound > lineLocation else {
            return nil
        }
        guard globalRange.overlaps(globalLineRange) else {
            return nil
        }
        if localToLine {
            let cappedLocation = max(globalRange.location - lineLocation, 0)
            let cappedLength = min(globalRange.length, lineLength - cappedLocation)
            self = NSRange(location: cappedLocation, length: cappedLength)
        } else {
            let cappedLocation = max(globalRange.location, lineLocation)
            let cappedLength = min(globalRange.length, lineLength)
            self = NSRange(location: cappedLocation, length: cappedLength)
        }
    }

    /// Checks if range overlaps another range.
    /// - Parameter range: Range to check against.
    /// - Returns: True if the ranges overlap otherwise false.
    func overlaps(_ range: NSRange) -> Bool {
        let r1 = location ..< location + length
        let r2 = range.location ..< range.location + range.length
        return r1.overlaps(r2)
    }

    /// Returns a range that is guaranteed not to have a negative length. As an example the range (20, -4) will be converted to (16, 4)
    /// and the range (20, -25) will be converted to (0, 20).
    var nonNegativeLength: NSRange {
        if length < 0 {
            let absoluteLength = abs(length)
            let safeAbsoluteLength = min(absoluteLength, location)
            return NSRange(location: location - safeAbsoluteLength, length: safeAbsoluteLength)
        } else {
            return self
        }
    }
}
