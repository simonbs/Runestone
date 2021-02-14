//
//  TreeSitterCapture.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

final class TreeSitterCapture {
    let byteRange: ByteRange
    let name: String

    init(byteRange: ByteRange, name: String) {
        self.byteRange = byteRange
        self.name = name
    }
}

extension TreeSitterCapture: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterCapture byteRange=\(byteRange.debugDescription) name=\(name)]"
    }
}
