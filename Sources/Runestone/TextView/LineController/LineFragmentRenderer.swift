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
        drawHighlightedRanges(to: context, inCanvasOfSize: canvasSize)
        drawMarkedRange(to: context)
        drawInvisibleCharacters()
        drawText(to: context)
        drawSpellingUnderlines(to: context)
    }

    /// A horizontally scrolled viewport can cover disjoint logical ranges in bidirectional text.
    func visibleCharacterRanges(in horizontalRange: ClosedRange<CGFloat>) -> [NSRange] {
        let runs = CTLineGetGlyphRuns(lineFragment.line) as? [CTRun] ?? []
        return runs.compactMap { run in
            guard let bounds = horizontalBounds(of: run), bounds.overlaps(horizontalRange) else {
                return nil
            }
            let stringRange = CTRunGetStringRange(run)
            let runRange = NSRange(location: stringRange.location, length: stringRange.length)
            let isRightToLeft = CTRunGetStatus(run).contains(.rightToLeft)
            let startIndex = horizontalRange.lowerBound <= bounds.lowerBound
                ? (isRightToLeft ? runRange.upperBound : runRange.lowerBound)
                : CTLineGetStringIndexForPosition(lineFragment.line, CGPoint(x: horizontalRange.lowerBound, y: 0))
            let endIndex = horizontalRange.upperBound >= bounds.upperBound
                ? (isRightToLeft ? runRange.lowerBound : runRange.upperBound)
                : CTLineGetStringIndexForPosition(lineFragment.line, CGPoint(x: horizontalRange.upperBound, y: 0))
            let lowerBound = max(runRange.lowerBound, min(startIndex, endIndex))
            let upperBound = min(runRange.upperBound, max(startIndex, endIndex) + 1)
            guard lowerBound < upperBound else {
                return nil
            }
            return NSIntersectionRange(NSRange(location: lowerBound, length: upperBound - lowerBound), lineFragment.visibleRange)
        }
    }

    /// Split at directional runs so a logical word never underlines unrelated text in a bidirectional line.
    func spellingUnderlineSegments(in range: NSRange) -> [ClosedRange<CGFloat>] {
        let visibleRange = NSIntersectionRange(range, lineFragment.visibleRange)
        guard visibleRange.length > 0 else {
            return []
        }
        let runs = CTLineGetGlyphRuns(lineFragment.line) as? [CTRun] ?? []
        return runs.compactMap { run in
            let stringRange = CTRunGetStringRange(run)
            let runRange = NSRange(location: stringRange.location, length: stringRange.length)
            let intersection = NSIntersectionRange(visibleRange, runRange)
            guard intersection.length > 0, let bounds = horizontalBounds(of: run) else {
                return nil
            }
            let runMinX = bounds.lowerBound
            let runMaxX = bounds.upperBound
            let isRightToLeft = CTRunGetStatus(run).contains(.rightToLeft)
            // At a directional boundary Core Text's primary caret can belong to the adjacent run.
            // Use this run's edges at its boundaries, and caret offsets only inside the run.
            let startX = intersection.lowerBound == runRange.lowerBound
                ? (isRightToLeft ? runMaxX : runMinX)
                : CTLineGetOffsetForStringIndex(lineFragment.line, intersection.lowerBound, nil)
            let endX = intersection.upperBound == runRange.upperBound
                ? (isRightToLeft ? runMinX : runMaxX)
                : CTLineGetOffsetForStringIndex(lineFragment.line, intersection.upperBound, nil)
            let minX = max(runMinX, min(startX, endX))
            let maxX = min(runMaxX, max(startX, endX))
            return minX < maxX ? minX ... maxX : nil
        }
    }
}

private extension LineFragmentRenderer {
    private func horizontalBounds(of run: CTRun) -> ClosedRange<CGFloat>? {
        let count = CTRunGetGlyphCount(run)
        guard count > 0 else {
            return nil
        }
        // Read only the edges, even when an unwrapped line contains thousands of glyphs.
        var firstPosition: CGPoint = .zero
        var lastPosition: CGPoint = .zero
        var firstAdvance: CGSize = .zero
        var lastAdvance: CGSize = .zero
        CTRunGetPositions(run, CFRange(location: 0, length: 1), &firstPosition)
        CTRunGetPositions(run, CFRange(location: count - 1, length: 1), &lastPosition)
        CTRunGetAdvances(run, CFRange(location: 0, length: 1), &firstAdvance)
        CTRunGetAdvances(run, CFRange(location: count - 1, length: 1), &lastAdvance)
        let minX = min(firstPosition.x, lastPosition.x)
        let maxX = max(firstPosition.x + firstAdvance.width, lastPosition.x + lastAdvance.width)
        return minX ... maxX
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
        let baseline = lineFragment.scaledSize.height - lineFragment.descent
            - (lineFragment.scaledSize.height - lineFragment.baseSize.height) / 2
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
