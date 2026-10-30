import CoreText
import Foundation

/// Character and decoration geometry for one Core Text line fragment.
///
/// Character ranges use UTF-16 indices in the original attributed string.
/// Horizontal coordinates are relative to the Core Text line origin.
public struct CoreTextLineGeometry {
    let line: CTLine
    let visibleRange: NSRange

    /// Creates geometry for the visible UTF-16 range of a Core Text line.
    public init(line: CTLine, visibleRange: NSRange) {
        self.line = line
        self.visibleRange = visibleRange
    }

    /// Returns visible character ranges, which may be disjoint in bidirectional text.
    public func visibleCharacterRanges(in horizontalRange: ClosedRange<CGFloat>) -> [NSRange] {
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
    public func horizontalSegments(for range: NSRange) -> [ClosedRange<CGFloat>] {
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

/// Horizontal glyph extents relative to the Core Text line origin, independent of style.
public enum CoreTextRunGeometry {
    /// Returns the horizontal glyph extent of a run, or nil when it has no width.
    public static func horizontalBounds(of run: CTRun) -> ClosedRange<CGFloat>? {
        let count = CTRunGetGlyphCount(run)
        guard count > 0 else {
            return nil
        }
        var positions = [CGPoint](repeating: .zero, count: count)
        var advances = [CGSize](repeating: .zero, count: count)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
        return horizontalBounds(positions: positions, advances: advances)
    }

    static func horizontalBounds(positions: [CGPoint], advances: [CGSize]) -> ClosedRange<CGFloat>? {
        precondition(positions.count == advances.count)
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        for (position, advance) in zip(positions, advances) {
            let start = position.x
            let end = start + advance.width
            minX = min(minX, min(start, end))
            maxX = max(maxX, max(start, end))
        }
        return maxX > minX ? minX ... maxX : nil
    }
}
