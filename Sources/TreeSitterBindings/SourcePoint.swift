//
//  SourcePoint.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

public final class SourcePoint {
    public var row: CUnsignedInt {
        return rawValue.row
    }
    public var column: CUnsignedInt {
        return rawValue.row
    }

    let rawValue: TSPoint

    init(point: TSPoint) {
        self.rawValue = point
    }

    public init(row: CUnsignedInt, column: CUnsignedInt) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension SourcePoint: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "(row = \(row), column = \(column)"
    }
}
