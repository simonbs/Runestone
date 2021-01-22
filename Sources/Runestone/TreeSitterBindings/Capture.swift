//
//  Capture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

final class Capture {
    let byteRange: ByteRange
    let name: String

    init(byteRange: ByteRange, name: String) {
        self.byteRange = byteRange
        self.name = name
    }
}

extension Capture: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[\(byteRange.location) - \(byteRange.length)] \(name)"
    }
}
