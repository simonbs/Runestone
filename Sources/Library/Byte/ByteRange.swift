import Foundation

public struct ByteRange: Hashable {
    public let location: ByteCount
    public let length: ByteCount
    public var lowerBound: ByteCount {
        location
    }
    public var upperBound: ByteCount {
        location + length
    }
    public var isEmpty: Bool {
        length == 0
    }

    public init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    public init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
    }

    public init(utf16Range: NSRange) {
        self.location = ByteCount(utf16Range.location * 2)
        self.length = ByteCount(utf16Range.length * 2)
    }

    public func overlaps(_ otherRange: ByteRange) -> Bool {
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
