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
    private enum HorizontalPosition {
        case character(Int)
        case endOfLine
    }

    weak var delegate: LineFragmentRendererDelegate?
    var lineFragment: LineFragment
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    var highlightedRanges: [HighlightedRange] = []

    private var showInvisibleCharacters: Bool {
        return invisibleCharacterConfiguration.showTabs
            || invisibleCharacterConfiguration.showSpaces
            || invisibleCharacterConfiguration.showLineBreaks
    }

    init(lineFragment: LineFragment) {
        self.lineFragment = lineFragment
    }

    func draw(to context: CGContext) {
        drawHighlights(to: context)
        drawInvisibleCharacters(to: context)
        drawText(to: context)
    }
}

private extension LineFragmentRenderer {
    private func justRenderImage(ofSize size: CGSize) -> UIImage? {
        var resultingImage: UIImage?
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        if let context = UIGraphicsGetCurrentContext() {
            drawHighlights(to: context)
            drawInvisibleCharacters(to: context)
            drawText(to: context)
            if let cgImage = context.makeImage() {
                resultingImage = UIImage(cgImage: cgImage)
            }
        }
        UIGraphicsEndImageContext()
        return resultingImage
    }

    private func drawHighlights(to context: CGContext) {
        if !highlightedRanges.isEmpty {
            context.saveGState()
            for highlightedRange in highlightedRanges {
                let startLocation = highlightedRange.range.lowerBound
                let endLocation = highlightedRange.range.upperBound
                let startX = CTLineGetOffsetForStringIndex(lineFragment.line, startLocation, nil)
                let endX = CTLineGetOffsetForStringIndex(lineFragment.line, endLocation, nil)
                let rect = CGRect(x: startX, y: 0, width: endX - startX, height: lineFragment.scaledSize.height)
                context.setFillColor(highlightedRange.color.cgColor)
                context.fill(rect)
            }
            context.restoreGState()
        }
    }

    private func drawInvisibleCharacters(to context: CGContext) {
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
        for (indexInLineFragment, substring) in string.enumerated() {
            let indexInLine = textRange.location + indexInLineFragment
            if invisibleCharacterConfiguration.showSpaces && substring == Symbol.Character.space {
                draw(invisibleCharacterConfiguration.spaceSymbol, at: .character(indexInLine))
            } else if invisibleCharacterConfiguration.showTabs && substring == Symbol.Character.tab {
                draw(invisibleCharacterConfiguration.tabSymbol, at: .character(indexInLine))
            } else if invisibleCharacterConfiguration.showLineBreaks
                        && (substring == Symbol.Character.lineFeed || substring == Symbol.Character.carriageReturnLineFeed) {
                draw(invisibleCharacterConfiguration.lineBreakSymbol, at: .endOfLine)
            }
        }
    }

    private func draw(_ symbol: String, at horizontalPosition: HorizontalPosition) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: invisibleCharacterConfiguration.textColor,
            .font: invisibleCharacterConfiguration.font
        ]
        let size = symbol.size(withAttributes: attrs)
        let xPosition = xPosition(for: horizontalPosition)
        let yPosition = (lineFragment.scaledSize.height - size.height) / 2
        let rect = CGRect(x: xPosition, y: yPosition, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }

    private func xPosition(for horizontalPosition: HorizontalPosition) -> CGFloat {
        switch horizontalPosition {
        case .character(let index):
            return round(CTLineGetOffsetForStringIndex(lineFragment.line, index, nil))
        case .endOfLine:
            return CGFloat(round(CTLineGetTypographicBounds(lineFragment.line, nil, nil, nil)))
        }
    }
}
