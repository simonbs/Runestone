//
//  TextPoint+Helpers.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import Foundation

extension TextPoint {
    convenience init(_ linePosition: LinePosition) {
        self.init(row: UInt32(linePosition.lineNumber), column: UInt32(linePosition.column))
    }
}
