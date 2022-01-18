//
//  ByteRange.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

struct ByteRange: Hashable {
    let location: ByteCount
    let length: ByteCount
    var lowerBound: ByteCount {
        return location
    }
    var upperBound: ByteCount {
        return location + length
    }
    var isEmpty: Bool {
        return length == 0
    }

    init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
    }

    init(utf16Range: NSRange) {
        self.location = ByteCount(utf16Range.location * 2)
        self.length = ByteCount(utf16Range.length * 2)
    }

    func overlaps(_ otherRange: ByteRange) -> Bool {
        let r1 = location ... location + length
        let r2 = otherRange.location ... otherRange.location + otherRange.length
        return r1.overlaps(r2)
    }
}

extension ByteRange: CustomStringConvertible {
    var description: String {
        return "{\(location), \(length)}"
    }
}

extension ByteRange: CustomDebugStringConvertible {
    var debugDescription: String {
        return "{\(location), \(length)}"
    }
}
