import Foundation

package struct ByteRange: Hashable {
    package let location: ByteCount
    package let length: ByteCount
    package var lowerBound: ByteCount {
        location
    }
    package var upperBound: ByteCount {
        location + length
    }
    package var isEmpty: Bool {
        length == 0
    }

    package init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    package init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
    }

    package init(utf16Range: NSRange) {
        self.location = ByteCount(utf16Range.location * 2)
        self.length = ByteCount(utf16Range.length * 2)
    }

    package func overlaps(_ otherRange: ByteRange) -> Bool {
        let r1 = location ... location + length
        let r2 = otherRange.location ... otherRange.location + otherRange.length
        return r1.overlaps(r2)
    }
}

extension ByteRange: CustomStringConvertible {
    package var description: String {
        "{\(location), \(length)}"
    }
}

extension ByteRange: CustomDebugStringConvertible {
    package var debugDescription: String {
        "{\(location), \(length)}"
    }
}
