//
//  HighlighterLinePosition.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation

@objc public final class HighlighterLinePosition: NSObject {
    public let lineNumber: Int
    public let column: Int

    @objc public init(lineNumber: Int, column: Int) {
        self.lineNumber = lineNumber
        self.column = column
        super.init()
    }
}
