//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class SourcePoint {
    var row: CUnsignedInt {
        return rawValue.row
    }
    var column: CUnsignedInt {
        return rawValue.row
    }

    let rawValue: TSPoint

    init(point: TSPoint) {
        self.rawValue = point
    }

    init(row: CUnsignedInt, column: CUnsignedInt) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension SourcePoint: CustomDebugStringConvertible {
    var debugDescription: String {
        return "(row = \(row), column = \(column)"
    }
}
