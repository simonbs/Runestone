import Foundation

/// A range expressed in bytes of the editor’s UTF-16 text representation.
public struct ByteRange: Hashable {
    /// Starting byte offset.
    public let location: ByteCount
    /// Length in bytes.
    public let length: ByteCount
    /// Starting byte offset.
    public var lowerBound: ByteCount {
        location
    }
    /// End byte offset.
    public var upperBound: ByteCount {
        location + length
    }
    /// Whether the range has zero length.
    public var isEmpty: Bool {
        length == 0
    }

    /// Creates a byte range from a location and length.
    public init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    /// Creates a byte range from start and end offsets.
    public init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
    }

    /// Converts a UTF-16 code-unit range to a byte range.
    public init(utf16Range: NSRange) {
        self.location = ByteCount(utf16Range.location * 2)
        self.length = ByteCount(utf16Range.length * 2)
    }

    /// Returns whether the ranges overlap, including touching endpoints.
    public func overlaps(_ otherRange: Self) -> Bool {
        let r1 = location ... location + length
        let r2 = otherRange.location ... otherRange.location + otherRange.length
        return r1.overlaps(r2)
    }
}

extension ByteRange: CustomStringConvertible {
    public var description: String {
        "{\(location), \(length)}"
    }
}

extension ByteRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        "{\(location), \(length)}"
    }
}
