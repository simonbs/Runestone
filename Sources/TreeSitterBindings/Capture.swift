//
//  Capture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

public final class Capture {
    public let startByte: uint
    public let endByte: uint
    public let name: String

    public init(startByte: uint, endByte: uint, name: String) {
        self.startByte = startByte
        self.endByte = endByte
        self.name = name
    }
}

extension Capture: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[\(startByte) - \(endByte)] \(name)"
    }
}
