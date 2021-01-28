//
//  ByteCount.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

struct ByteCount: Hashable {
    private(set) var value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(_ value: UInt32) {
        self.value = Int(value)
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

extension ByteCount: AdditiveArithmetic {
    static var zero: ByteCount {
        return ByteCount(0)
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
