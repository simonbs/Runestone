import CoreText
import Foundation

/// Platform-neutral character and decoration geometry for one Core Text line fragment.
struct CoreTextLineGeometry {
    let line: CTLine
    let visibleRange: NSRange

    /// A horizontally scrolled viewport can cover disjoint logical ranges in bidirectional text.
    func visibleCharacterRanges(in horizontalRange: ClosedRange<CGFloat>) -> [NSRange] {
        glyphRuns.compactMap { run in
            guard let bounds = horizontalBounds(of: run), bounds.overlaps(horizontalRange) else {
                return nil
            }
            let stringRange = CTRunGetStringRange(run)
            let runRange = NSRange(location: stringRange.location, length: stringRange.length)
            let isRightToLeft = CTRunGetStatus(run).contains(.rightToLeft)
            let startIndex = horizontalRange.lowerBound <= bounds.lowerBound
                ? (isRightToLeft ? runRange.upperBound : runRange.lowerBound)
                : CTLineGetStringIndexForPosition(line, CGPoint(x: horizontalRange.lowerBound, y: 0))
            let endIndex = horizontalRange.upperBound >= bounds.upperBound
                ? (isRightToLeft ? runRange.lowerBound : runRange.upperBound)
                : CTLineGetStringIndexForPosition(line, CGPoint(x: horizontalRange.upperBound, y: 0))
            let lowerBound = max(runRange.lowerBound, min(startIndex, endIndex))
            let upperBound = min(runRange.upperBound, max(startIndex, endIndex) + 1)
            guard lowerBound < upperBound else {
                return nil
            }
            return NSIntersectionRange(NSRange(location: lowerBound, length: upperBound - lowerBound), visibleRange)
        }
    }

    /// Splits at directional runs so a logical word never decorates unrelated bidirectional text.
    func horizontalSegments(for range: NSRange) -> [ClosedRange<CGFloat>] {
        let clippedRange = NSIntersectionRange(range, visibleRange)
        guard clippedRange.length > 0 else {
            return []
        }
        return glyphRuns.compactMap { run in
            let stringRange = CTRunGetStringRange(run)
            let runRange = NSRange(location: stringRange.location, length: stringRange.length)
            let intersection = NSIntersectionRange(clippedRange, runRange)
            guard intersection.length > 0, let bounds = horizontalBounds(of: run) else {
                return nil
            }
            let isRightToLeft = CTRunGetStatus(run).contains(.rightToLeft)
            // A primary caret at a directional boundary can belong to the adjacent run.
            let startX = intersection.lowerBound == runRange.lowerBound
                ? (isRightToLeft ? bounds.upperBound : bounds.lowerBound)
                : CTLineGetOffsetForStringIndex(line, intersection.lowerBound, nil)
            let endX = intersection.upperBound == runRange.upperBound
                ? (isRightToLeft ? bounds.lowerBound : bounds.upperBound)
                : CTLineGetOffsetForStringIndex(line, intersection.upperBound, nil)
            let minX = max(bounds.lowerBound, min(startX, endX))
            let maxX = min(bounds.upperBound, max(startX, endX))
            return minX < maxX ? minX ... maxX : nil
        }
    }
}

private extension CoreTextLineGeometry {
    var glyphRuns: [CTRun] {
        CTLineGetGlyphRuns(line) as? [CTRun] ?? []
    }

    func horizontalBounds(of run: CTRun) -> ClosedRange<CGFloat>? {
        let count = CTRunGetGlyphCount(run)
        guard count > 0 else {
            return nil
        }
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
}
