//
//  TypesetLine.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreText

final class TypesetLine {
    let line: CTLine
    let descent: CGFloat
    let size: CGSize
    let yPosition: CGFloat

    init(line: CTLine, descent: CGFloat, size: CGSize, yPosition: CGFloat) {
        self.line = line
        self.descent = descent
        self.size = size
        self.yPosition = yPosition
    }
}
