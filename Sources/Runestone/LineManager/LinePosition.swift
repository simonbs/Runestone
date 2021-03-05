//
//  LinePosition.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

public final class LinePosition {
    public let row: Int
    public let column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    convenience init(_ point: TreeSitterTextPoint) {
        self.init(row: Int(point.row), column: Int(point.column))
    }
}

extension LinePosition: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[LinePosition row=\(row) column=\(column)]"
    }
}
