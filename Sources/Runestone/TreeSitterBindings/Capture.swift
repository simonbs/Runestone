//
//  Capture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

final class Capture {
    let startByte: uint
    let endByte: uint
    let name: String

    init(startByte: uint, endByte: uint, name: String) {
        self.startByte = startByte
        self.endByte = endByte
        self.name = name
    }
}

extension Capture: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[\(startByte) - \(endByte)] \(name)"
    }
}
