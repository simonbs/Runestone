//
//  LinePosition.swift
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

import Foundation

@objc public final class LinePosition: NSObject {
    @objc public let lineNumber: Int
    @objc public let column: Int

    init(lineNumber: Int, column: Int) {
        self.lineNumber = lineNumber
        self.column = column
        super.init()
    }
}
