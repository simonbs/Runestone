//
//  LinePosition.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

public final class LinePosition {
    public let lineStartLocation: Int
    public let lineNumber: Int
    public let column: Int
    public let totalLength: Int

    init(lineStartLocation: Int, lineNumber: Int, column: Int, totalLength: Int) {
        self.lineStartLocation = lineStartLocation
        self.lineNumber = lineNumber
        self.column = column
        self.totalLength = totalLength
    }
}
