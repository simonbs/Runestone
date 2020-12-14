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
    @objc public let length: Int

    init(lineNumber: Int, column: Int, length: Int) {
        self.lineNumber = lineNumber
        self.column = column
        self.length = length
        super.init()
    }
}
