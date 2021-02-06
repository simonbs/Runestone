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
    let baseSize: CGSize
    let scaledSize: CGSize
    let yPosition: CGFloat

    init(line: CTLine, descent: CGFloat, baseSize: CGSize, scaledSize: CGSize, yPosition: CGFloat) {
        self.line = line
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
    }
}
