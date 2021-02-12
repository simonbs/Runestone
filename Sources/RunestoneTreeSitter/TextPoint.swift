//
//  TextPoint.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

public final class TextPoint {
    public var row: UInt32 {
        return rawValue.row
    }
    public var column: UInt32 {
        return rawValue.column
    }

    let rawValue: TSPoint

    init(_ point: TSPoint) {
        self.rawValue = point
    }

    public init(row: UInt32, column: UInt32) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension TextPoint: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[TextPoint row=\(row) column=\(column)]"
    }
}
