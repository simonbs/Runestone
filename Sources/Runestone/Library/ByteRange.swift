//
//  File.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

public struct ByteRange: Hashable {
    public let location: ByteCount
    public let length: ByteCount
    public var lowerBound: ByteCount {
        return location
    }
    public var upperBound: ByteCount {
        return location + length
    }
    public var isEmpty: Bool {
        return length.value == 0
    }

    public init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    public init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
    }

    public func overlaps(_ otherRange: ByteRange) -> Bool {
        let r1 = location ... location + length
        let r2 = otherRange.location ... otherRange.location + otherRange.length
        return r1.overlaps(r2)
    }
}

extension ByteRange: CustomStringConvertible {
    public var description: String {
        return "{\(location), \(length)}"
    }
}

extension ByteRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "{\(location), \(length)}"
    }
}
