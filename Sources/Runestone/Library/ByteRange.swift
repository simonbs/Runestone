//
//  File.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

struct ByteRange: Hashable {
    let location: ByteCount
    let length: ByteCount

    init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
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
