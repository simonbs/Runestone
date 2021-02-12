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

    public init(location: ByteCount, length: ByteCount) {
        self.location = location
        self.length = length
    }

    public  init(from startByte: ByteCount, to endByte: ByteCount) {
        self.location = startByte
        self.length = endByte - startByte
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
