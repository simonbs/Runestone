import CoreText
import RunestoneEngine
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
    let invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    var markedRange: NSRange?
    var markedTextBackgroundColor: UIColor = .systemFill
    var markedTextBackgroundCornerRadius: CGFloat = 0
    var highlightedRangeFragments: [HighlightedRangeFragment] = []
    var misspelledRanges: [NSRange] = []

    private var showInvisibleCharacters: Bool {
        invisibleCharacterConfiguration.showTabs
            || invisibleCharacterConfiguration.showSpaces
            || invisibleCharacterConfiguration.showLineBreaks
            || invisibleCharacterConfiguration.showSoftLineBreaks
    }

    init(lineFragment: LineFragment, invisibleCharacterConfiguration: InvisibleCharacterConfiguration) {
        self.lineFragment = lineFragment
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
    }

    func draw(to context: CGContext, inCanvasOfSize canvasSize: CGSize) {
        drawTokenBackgrounds(to: context)
        drawHighlightedRanges(to: context, inCanvasOfSize: canvasSize)
        drawMarkedRange(to: context)
        drawInvisibleCharacters()
        drawText(to: context)
        drawSpellingUnderlines(to: context)
    }

    /// A horizontally scrolled viewport can cover disjoint logical ranges in bidirectional text.
    func visibleCharacterRanges(in horizontalRange: ClosedRange<CGFloat>) -> [NSRange] {
        geometry.visibleCharacterRanges(in: horizontalRange)
    }

    /// Split at directional runs so a logical word never underlines unrelated text in a bidirectional line.
    func spellingUnderlineSegments(in range: NSRange) -> [ClosedRange<CGFloat>] {
        geometry.horizontalSegments(for: range)
    }
}

private extension LineFragmentRenderer {
    private func drawTokenBackgrounds(to context: CGContext) {
        // Paint token backgrounds separately from glyphs to keep overlays visible.
        // Runs are visual segments, so their glyph positions also handle mixed writing
        // directions and avoid spanning unrelated text across a bidirectional boundary.
        context.saveGState()
        defer { context.restoreGState() }
        for run in CTLineGetGlyphRuns(lineFragment.line) as? [CTRun] ?? [] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let color = attributes[NSAttributedString.Key.tokenBackgroundColor] as? UIColor else {
                continue
            }
            guard let bounds = CoreTextRunGeometry.horizontalBounds(of: run) else {
                continue
            }
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: bounds.lowerBound, y: 0, width: bounds.upperBound - bounds.lowerBound,
                                height: lineFragment.scaledSize.height))
        }
    }

    private var geometry: CoreTextLineGeometry {
        CoreTextLineGeometry(line: lineFragment.line, visibleRange: lineFragment.visibleRange)
    }

    private func drawSpellingUnderlines(to context: CGContext) {
        guard !misspelledRanges.isEmpty else {
            return
        }
        context.saveGState()
        context.setStrokeColor(UIColor.systemRed.cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.setLineDash(phase: 0, lengths: [0, 3])
        let baseline = lineFragment.verticalGeometry.topDownBaseline
        let underlineY = min(baseline + max(1.5, lineFragment.descent / 2), lineFragment.scaledSize.height - 1)
        for range in misspelledRanges {
            for segment in spellingUnderlineSegments(in: range) {
                context.move(to: CGPoint(x: segment.lowerBound, y: underlineY))
                context.addLine(to: CGPoint(x: segment.upperBound, y: underlineY))
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    private func drawHighlightedRanges(to context: CGContext, inCanvasOfSize canvasSize: CGSize) {
        guard !highlightedRangeFragments.isEmpty else {
            return
        }
        context.saveGState()
        for highlightedRange in highlightedRangeFragments {
            let startX = CTLineGetOffsetForStringIndex(lineFragment.line, highlightedRange.range.lowerBound, nil)
            let endX: CGFloat
            if shouldHighlightLineEnding(for: highlightedRange) {
                endX = canvasSize.width
            } else {
                endX = CTLineGetOffsetForStringIndex(lineFragment.line, highlightedRange.range.upperBound, nil)
            }
            let rect = CGRect(x: startX, y: 0, width: endX - startX, height: lineFragment.scaledSize.height)
            let roundedCorners = highlightedRange.roundedCorners
            context.setFillColor(highlightedRange.color.cgColor)
            if !roundedCorners.isEmpty && highlightedRange.cornerRadius > 0 {
                let cornerRadii = CGSize(width: highlightedRange.cornerRadius, height: highlightedRange.cornerRadius)
                let bezierPath = UIBezierPath(roundedRect: rect, byRoundingCorners: roundedCorners, cornerRadii: cornerRadii)
                context.addPath(bezierPath.cgPath)
                context.fillPath()
            } else {
                context.fill(rect)
            }
        }
        context.restoreGState()
    }

    private func drawMarkedRange(to context: CGContext) {
        if let markedRange = markedRange {
            context.saveGState()
            let startX = CTLineGetOffsetForStringIndex(lineFragment.line, markedRange.lowerBound, nil)
            let endX = CTLineGetOffsetForStringIndex(lineFragment.line, markedRange.upperBound, nil)
            let rect = CGRect(x: startX, y: 0, width: endX - startX, height: lineFragment.scaledSize.height)
            context.setFillColor(markedTextBackgroundColor.cgColor)
            if markedTextBackgroundCornerRadius > 0 {
                let cornerRadius = markedTextBackgroundCornerRadius
                let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                context.addPath(path)
                context.fillPath()
            } else {
                context.fill(rect)
            }
            context.restoreGState()
        }
    }

    private func drawInvisibleCharacters() {
        if showInvisibleCharacters, let string = delegate?.string(in: self) {
            drawInvisibleCharacters(in: string)
        }
    }

    private func drawInvisibleCharacters(in string: String) {
        var indexInLineFragment = 0
        for substring in string {
            let indexInLine = lineFragment.visibleRange.location + indexInLineFragment
            indexInLineFragment += substring.utf16.count
            if invisibleCharacterConfiguration.showSpaces && substring == Symbol.Character.space {
                draw(invisibleCharacterConfiguration.spaceSymbol, at: .character(indexInLine))
            } else if invisibleCharacterConfiguration.showNonBreakingSpaces && substring == Symbol.Character.nonBreakingSpace {
                draw(invisibleCharacterConfiguration.nonBreakingSpaceSymbol, at: .character(indexInLine))
            } else if invisibleCharacterConfiguration.showTabs && substring == Symbol.Character.tab {
                draw(invisibleCharacterConfiguration.tabSymbol, at: .character(indexInLine))
            } else if invisibleCharacterConfiguration.showLineBreaks && isLineBreak(substring) {
                draw(invisibleCharacterConfiguration.lineBreakSymbol, at: .endOfLine)
            } else if invisibleCharacterConfiguration.showSoftLineBreaks && substring == Symbol.Character.lineSeparator {
                draw(invisibleCharacterConfiguration.softLineBreakSymbol, at: .endOfLine)
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
            return CTLineGetOffsetForStringIndex(lineFragment.line, index, nil)
        case .endOfLine:
            return CGFloat(CTLineGetTypographicBounds(lineFragment.line, nil, nil, nil))
        }
    }

    private func shouldHighlightLineEnding(for highlightedRangeFragment: HighlightedRangeFragment) -> Bool {
        guard highlightedRangeFragment.range.upperBound == lineFragment.range.upperBound else {
            return false
        }
        guard let string = delegate?.string(in: self), let lastCharacter = string.last else {
            return false
        }
        return isLineBreak(lastCharacter)
    }

    private func isLineBreak(_ string: String.Element) -> Bool {
        string == Symbol.Character.lineFeed || string == Symbol.Character.carriageReturn || string == Symbol.Character.carriageReturnLineFeed
    }
}

extension LineFragmentRenderer {
    func drawText(to context: CGContext) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: lineFragment.scaledSize.height)
        context.scaleBy(x: 1, y: -1)
        let yPosition = lineFragment.verticalGeometry.coreTextBaseline
        context.textPosition = CGPoint(x: 0, y: yPosition)
        CTLineDraw(lineFragment.line, context)
        context.restoreGState()
    }

}
