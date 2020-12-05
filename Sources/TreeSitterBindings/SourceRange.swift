//
//  File.swift
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

    private let rawValue: TSRange

    init(startPoint: SourcePoint, endPoint: SourcePoint, startByte: UInt32, endByte: UInt32) {
        self.rawValue = TSRange(start_point: startPoint.rawValue, end_point: endPoint.rawValue, start_byte: startByte, end_byte: endByte)
    }
}

extension SourceRange: CustomDebugStringConvertible {
    var debugDescription: String {
        return "(\(startPoint.debugDescription) - \(endPoint.debugDescription))"
    }
}
