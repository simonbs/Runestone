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
            let yPosition = typesetLine.descent + (lineViewFrame.height - typesetLine.yPosition - typesetLine.size.height)
            context.textPosition = CGPoint(x: 0, y: yPosition)
            CTLineDraw(typesetLine.line, context)
        }
        context.restoreGState()
    }

    private func drawInvisibleCharacters(in preparedLine: TypesetLine, of string: String, to context: CGContext) {
        let textRange = CTLineGetStringRange(preparedLine.line)
        let stringRange = Range(NSRange(location: textRange.location, length: textRange.length), in: string)!
        let lineString = string[stringRange]
        for (index, substring) in lineString.enumerated() {
            if invisibleCharacterConfiguration.showSpaces && substring == Symbol.Character.space {
                let xPosition = round(CTLineGetOffsetForStringIndex(preparedLine.line, index, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: preparedLine.yPosition)
                draw(invisibleCharacterConfiguration.spaceSymbol, at: point)
            } else if invisibleCharacterConfiguration.showTabs && substring == Symbol.Character.tab {
                let xPosition = round(CTLineGetOffsetForStringIndex(preparedLine.line, index, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: preparedLine.yPosition)
                draw(invisibleCharacterConfiguration.tabSymbol, at: point)
            } else if invisibleCharacterConfiguration.showLineBreaks && substring == Symbol.Character.lineFeed {
                let xPosition = round(CTLineGetTypographicBounds(preparedLine.line, nil, nil, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: preparedLine.yPosition)
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
