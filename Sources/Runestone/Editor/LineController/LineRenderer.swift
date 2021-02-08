//
//  LineRenderer.swift
//  
//
//  Created by Simon Støvring on 06/02/2021.
//

import CoreText
import UIKit

final class LineRenderer {
    var lineViewFrame: CGRect = .zero
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()

    private let typesetter: LineTypesetter
    private var showInvisibleCharacters: Bool {
        return invisibleCharacterConfiguration.showTabs
            || invisibleCharacterConfiguration.showSpaces
            || invisibleCharacterConfiguration.showLineBreaks
    }

    init(typesetter: LineTypesetter) {
        self.typesetter = typesetter
    }

    func draw(_ string: String, to context: CGContext) {
        drawBackground(for: string, to: context)
        drawText(to: context)
    }
}

private extension LineRenderer {
    private func drawBackground(for string: String, to context: CGContext) {
        if showInvisibleCharacters {
            for typesetLine in typesetter.typesetLines {
                drawInvisibleCharacters(in: typesetLine, of: string, to: context)
            }
        }
    }

    private func drawText(to context: CGContext) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: lineViewFrame.height)
        context.scaleBy(x: 1, y: -1)
        for typesetLine in typesetter.typesetLines {
            let yPosition = typesetLine.descent + (lineViewFrame.height - typesetLine.yPosition - typesetLine.baseSize.height)
            let yOffset = (typesetLine.scaledSize.height - typesetLine.baseSize.height) / 2
            context.textPosition = CGPoint(x: 0, y: yPosition - yOffset)
            CTLineDraw(typesetLine.line, context)
        }
        context.restoreGState()
    }

    private func drawInvisibleCharacters(in typesetLine: TypesetLine, of string: String, to context: CGContext) {
        let textRange = CTLineGetStringRange(typesetLine.line)
        let stringRange = Range(NSRange(location: textRange.location, length: textRange.length), in: string)!
        let lineString = string[stringRange]
        for (indexInLineFragment, substring) in lineString.enumerated() {
            let indexInLine = textRange.location + indexInLineFragment
            let yPosition = typesetLine.yPosition + (typesetLine.scaledSize.height - typesetLine.baseSize.height) / 2
            if invisibleCharacterConfiguration.showSpaces && substring == Symbol.Character.space {
                let xPosition = round(CTLineGetOffsetForStringIndex(typesetLine.line, indexInLine, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: yPosition)
                draw(invisibleCharacterConfiguration.spaceSymbol, at: point)
            } else if invisibleCharacterConfiguration.showTabs && substring == Symbol.Character.tab {
                let xPosition = round(CTLineGetOffsetForStringIndex(typesetLine.line, indexInLine, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: yPosition)
                draw(invisibleCharacterConfiguration.tabSymbol, at: point)
            } else if invisibleCharacterConfiguration.showLineBreaks && substring == Symbol.Character.lineFeed || substring == Symbol.Character.carriageReturnLineFeed {
                let xPosition = round(CTLineGetTypographicBounds(typesetLine.line, nil, nil, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: yPosition)
                draw(invisibleCharacterConfiguration.lineBreakSymbol, at: point)
            }
        }
    }

    private func draw(_ symbol: String, at point: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: invisibleCharacterConfiguration.textColor,
            .font: invisibleCharacterConfiguration.font
        ]
        let size = symbol.size(withAttributes: attrs)
        let rect = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }
}
