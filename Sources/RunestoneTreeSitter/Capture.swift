//
//  Capture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation
import RunestoneUtils

public final class Capture {
    public let byteRange: ByteRange
    public let name: String

    init(byteRange: ByteRange, name: String) {
        self.byteRange = byteRange
        self.name = name
    }
}

extension Capture: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[\(byteRange.location) - \(byteRange.length)] \(name)"
    }
}
