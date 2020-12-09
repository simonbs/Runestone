//
//  File.swift
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

import Foundation

@objc public final class LinePosition: NSObject {
    @objc public let line: Int
    @objc public let column: Int

    init(line: Int, column: Int) {
        self.line = line
        self.column = column
        super.init()
    }
}
