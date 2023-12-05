import Foundation

package struct ByteCount: Hashable {
    package private(set) var value: Int
    package var utf16Length: Int {
        value / 2
    }

    package init(_ value: Int) {
        self.value = value
    }

    package init(_ value: UInt32) {
        self.value = Int(value)
    }

    package init(utf16Length: Int) {
        self.value = utf16Length * 2
    }
}

extension ByteCount: CustomStringConvertible {
    package var description: String {
        "\(value)"
    }
}

extension ByteCount: CustomDebugStringConvertible {
    package var debugDescription: String {
        "\(value)"
    }
}

extension ByteCount: Numeric {
    package typealias Magnitude = Int
    package typealias IntegerLiteralType = Int

    package static var zero: ByteCount {
        ByteCount(0)
    }

    package var magnitude: Int {
        value
    }

    package init?<T>(exactly source: T) where T: BinaryInteger {
        self.init(Int(source))
    }

    package init(integerLiteral value: Int) {
        self.init(value)
    }

    package static func - (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(lhs.value - rhs.value)
    }

    package static func -= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value -= rhs.value
    }

    package static func + (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(lhs.value + rhs.value)
    }

    package static func += (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value += rhs.value
    }

    package static func * (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(lhs.value * rhs.value)
    }

    package static func *= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value *= rhs.value
    }
}

extension ByteCount: Comparable {
    package static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value < rhs.value
    }

    package static func <= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value <= rhs.value
    }

    package static func >= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value >= rhs.value
    }

    package static func > (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value > rhs.value
    }
}
