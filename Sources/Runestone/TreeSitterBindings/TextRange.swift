//
//  TextRange.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class TextRange {
    var startPoint: TextPoint {
        return TextPoint(row: rawValue.start_point.row, column: rawValue.start_point.column)
    }
    var endPoint: TextPoint {
        return TextPoint(row: rawValue.end_point.row, column: rawValue.end_point.column)
    }
    var startByte: ByteCount {
        return ByteCount(rawValue.start_byte)
    }
    var endByte: ByteCount {
        return ByteCount(rawValue.end_byte)
    }

    private let rawValue: TSRange

    init(startPoint: TextPoint, endPoint: TextPoint, startByte: ByteCount, endByte: ByteCount) {
        self.rawValue = TSRange(
            start_point: startPoint.rawValue,
            end_point: endPoint.rawValue,
            start_byte: UInt32(startByte.value),
            end_byte: UInt32(endByte.value))
    }
}

extension TextRange: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TextRange startByte=\(startByte) endByte=\(endByte) startPoint=\(startPoint) endPoint=\(endPoint)]"
    }
}
