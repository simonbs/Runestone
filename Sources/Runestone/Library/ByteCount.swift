//
//  ByteCount.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

struct ByteCount: Hashable {
    private(set) var value: Int
    var utf16Length: Int {
        return value / 2
    }

    init(_ value: Int) {
        self.value = value
    }

    init(_ value: UInt32) {
        self.value = Int(value)
    }

    init(utf16Length: Int) {
        self.value = utf16Length * 2
    }
}

extension ByteCount: Comparable {
    static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value < rhs.value
    }

    static func <= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value <= rhs.value
    }

    static func >= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value >= rhs.value
    }

    static func > (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value > rhs.value
    }
}

extension ByteCount: Numeric {
    typealias Magnitude = Int
    typealias IntegerLiteralType = Int

    static var zero: ByteCount {
        return ByteCount(0)
    }

    var magnitude: Int {
        return value
    }

    init?<T>(exactly source: T) where T: BinaryInteger {
        self.value = Int(source)
    }

    init(integerLiteral value: Int) {
        self.value = value
    }

    static func - (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        return ByteCount(lhs.value - rhs.value)
    }

    static func -= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value -= rhs.value
    }

    static func + (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        return ByteCount(lhs.value + rhs.value)
    }

    static func += (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value += rhs.value
    }

    static func * (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        return ByteCount(lhs.value * rhs.value)
    }

    static func *= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value *= rhs.value
    }
}

extension ByteCount: CustomStringConvertible {
    var description: String {
        return "\(value)"
    }
}

extension ByteCount: CustomDebugStringConvertible {
    var debugDescription: String {
        return "\(value)"
    }
}
