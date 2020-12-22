//
//  LinePosition.swift
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

import Foundation

public final class LinePosition {
    public let lineNumber: Int
    public let column: Int
    public let length: Int

    init(lineNumber: Int, column: Int, length: Int) {
        self.lineNumber = lineNumber
        self.column = column
        self.length = length
    }
}
