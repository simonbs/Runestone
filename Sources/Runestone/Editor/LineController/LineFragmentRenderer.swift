//
//  LineFragmentRenderer.swift
//  
//
//  Created by Simon Støvring on 06/02/2021.
//

import CoreText
import UIKit

protocol LineFragmentRendererDelegate: AnyObject {
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String?
}

final class LineFragmentRenderer {
    weak var delegate: LineFragmentRendererDelegate?
    var lineFragment: LineFragment
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()

    private var showInvisibleCharacters: Bool {
        return invisibleCharacterConfiguration.showTabs
            || invisibleCharacterConfiguration.showSpaces
            || invisibleCharacterConfiguration.showLineBreaks
    }

    init(lineFragment: LineFragment) {
        self.lineFragment = lineFragment
    }

    func draw(to context: CGContext) {
        drawBackground(to: context)
        drawText(to: context)
    }
}

private extension LineFragmentRenderer {
    private func drawBackground(to context: CGContext) {
        if showInvisibleCharacters {
            if let string = delegate?.string(in: self) {
                drawInvisibleCharacters(in: string, to: context)
            }
        }
    }

    private func drawText(to context: CGContext) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: lineFragment.scaledSize.height)
        context.scaleBy(x: 1, y: -1)
        let yPosition = lineFragment.descent + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
        context.textPosition = CGPoint(x: 0, y: yPosition)
        CTLineDraw(lineFragment.line, context)
        context.restoreGState()
    }

    private func drawInvisibleCharacters(in string: String, to context: CGContext) {
        let textRange = CTLineGetStringRange(lineFragment.line)
        let stringRange = Range(NSRange(location: textRange.location, length: textRange.length), in: string)!
        let lineString = string[stringRange]
        for (indexInLineFragment, substring) in lineString.enumerated() {
            let indexInLine = textRange.location + indexInLineFragment
            if invisibleCharacterConfiguration.showSpaces && substring == Symbol.Character.space {
                let xPosition = round(CTLineGetOffsetForStringIndex(lineFragment.line, indexInLine, nil))
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
                let point = CGPoint(x: CGFloat(xPosition), y: yPosition)
                draw(invisibleCharacterConfiguration.spaceSymbol, at: point)
            } else if invisibleCharacterConfiguration.showTabs && substring == Symbol.Character.tab {
                let xPosition = round(CTLineGetOffsetForStringIndex(lineFragment.line, indexInLine, nil))
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
                let point = CGPoint(x: CGFloat(xPosition), y: yPosition)
                draw(invisibleCharacterConfiguration.tabSymbol, at: point)
            } else if invisibleCharacterConfiguration.showLineBreaks && substring == Symbol.Character.lineFeed || substring == Symbol.Character.carriageReturnLineFeed {
                let xPosition = round(CTLineGetTypographicBounds(lineFragment.line, nil, nil, nil))
                let yPosition = lineFragment.yPosition + (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
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
