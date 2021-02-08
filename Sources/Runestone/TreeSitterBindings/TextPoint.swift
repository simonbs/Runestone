//
//  TextPoint.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class TextPoint {
    public var row: CUnsignedInt {
        return rawValue.row
    }
    var column: CUnsignedInt {
        return rawValue.column
    }

    let rawValue: TSPoint

    init(_ point: TSPoint) {
        self.rawValue = point
    }

    init(row: CUnsignedInt, column: CUnsignedInt) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension TextPoint: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TextPoint row=\(row) column=\(column)]"
    }
}
