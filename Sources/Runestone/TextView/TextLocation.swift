//
//  TextLocation.swift
//  
//
//  Created by Simon on 18/01/2022.
//

import Foundation

/// A location in the text.
public struct TextLocation: Hashable, Equatable {
    /// Zero-based line number.
    public let lineNumber: Int
    /// Column in the line.
    public let column: Int

    init(_ linePosition: LinePosition) {
        self.lineNumber = linePosition.row
        self.column = linePosition.column
    }
}
