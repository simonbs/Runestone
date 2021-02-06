//
//  LineRenderer.swift
//  
//
//  Created by Simon Støvring on 06/02/2021.
//

import CoreGraphics
import CoreText

final class LineRenderer {
    var lineViewFrame: CGRect = .zero

    private let typesetter: LineTypesetter

    init(typesetter: LineTypesetter) {
        self.typesetter = typesetter
    }

    func draw(to context: CGContext) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: lineViewFrame.height)
        context.scaleBy(x: 1, y: -1)
        for typesetLine in typesetter.typesetLines {
            let yPosition = typesetLine.descent + (lineViewFrame.height - typesetLine.yPosition - typesetLine.size.height)
            context.textPosition = CGPoint(x: 0, y: yPosition)
            CTLineDraw(typesetLine.line, context)
        }
        context.restoreGState()
    }
}
