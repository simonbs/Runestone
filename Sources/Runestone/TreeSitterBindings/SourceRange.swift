//
//  SourceRange.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class SourceRange {
    var startPoint: SourcePoint {
        return SourcePoint(row: rawValue.start_point.row, column: rawValue.start_point.column)
    }
    var endPoint: SourcePoint {
        return SourcePoint(row: rawValue.end_point.row, column: rawValue.end_point.column)
    }
    var startByte: ByteCount {
        return ByteCount(rawValue.start_byte)
    }
    var endByte: ByteCount {
        return ByteCount(rawValue.end_byte)
    }

    private let rawValue: TSRange

    init(startPoint: SourcePoint, endPoint: SourcePoint, startByte: ByteCount, endByte: ByteCount) {
        self.rawValue = TSRange(
            start_point: startPoint.rawValue,
            end_point: endPoint.rawValue,
            start_byte: UInt32(startByte.value),
            end_byte: UInt32(endByte.value))
    }
}

extension SourceRange: CustomDebugStringConvertible {
    var debugDescription: String {
        return "(\(startPoint.debugDescription) - \(endPoint.debugDescription))"
    }
}
