import Foundation

public struct ByteCount: Hashable {
    public private(set) var value: Int
    public var utf16Length: Int {
        value / 2
    }

    public init(_ value: Int) {
        self.value = value
    }

    public init(_ value: UInt32) {
        self.value = Int(value)
    }

    public init(utf16Length: Int) {
        self.value = utf16Length * 2
    }
}

extension ByteCount: CustomStringConvertible {
    public var description: String {
        "\(value)"
    }
}

extension ByteCount: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(value)"
    }
}

extension ByteCount: Numeric {
    public typealias Magnitude = Int
    public typealias IntegerLiteralType = Int

    public static var zero: ByteCount {
        ByteCount(0)
    }

    public var magnitude: Int {
        value
    }

    public init?<T>(exactly source: T) where T: BinaryInteger {
        self.init(Int(source))
    }

    public init(integerLiteral value: Int) {
        self.init(value)
    }

    public static func - (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(lhs.value - rhs.value)
    }

    public static func -= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value -= rhs.value
    }

    public static func + (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(lhs.value + rhs.value)
    }

    public static func += (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value += rhs.value
    }

    public static func * (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        ByteCount(lhs.value * rhs.value)
    }

    public static func *= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value *= rhs.value
    }
}

extension ByteCount: Comparable {
    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value < rhs.value
    }

    public static func <= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value <= rhs.value
    }

    public static func >= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value >= rhs.value
    }

    public static func > (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.value > rhs.value
    }
}
