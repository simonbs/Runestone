//
//  LinePosition.swift
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

import Foundation

public final class LinePosition {
    public let lineStartLocation: Int
    public let lineNumber: Int
    public let column: Int
    public let length: Int
    public let delimiterLength: Int
    public var totalLength: Int {
        return length + delimiterLength
    }

    init(lineStartLocation: Int, lineNumber: Int, column: Int, length: Int, delimiterLength: Int) {
        self.lineStartLocation = lineStartLocation
        self.lineNumber = lineNumber
        self.column = column
        self.length = length
        self.delimiterLength = delimiterLength
    }
}
