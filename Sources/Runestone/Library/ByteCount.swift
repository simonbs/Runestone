//
//  ByteCount.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

public struct ByteCount: Hashable {
    public private(set) var value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public init(_ value: UInt32) {
        self.value = Int(value)
    }
}

extension ByteCount: Comparable {
    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value < rhs.value
    }
    
    public static func <= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value <= rhs.value
    }

    public static func >= (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value >= rhs.value
    }

    public static func > (lhs: ByteCount, rhs: ByteCount) -> Bool {
        return lhs.value > rhs.value
    }
}

extension ByteCount: AdditiveArithmetic {
    public static var zero: ByteCount {
        return ByteCount(0)
    }

    public static func - (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        return ByteCount(lhs.value - rhs.value)
    }

    public static func -= (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value -= rhs.value
    }

    public static func + (lhs: ByteCount, rhs: ByteCount) -> ByteCount {
        return ByteCount(lhs.value + rhs.value)
    }

    public static func += (lhs: inout ByteCount, rhs: ByteCount) {
        lhs.value += rhs.value
    }
}

extension ByteCount: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}

extension ByteCount: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(value)"
    }
}
