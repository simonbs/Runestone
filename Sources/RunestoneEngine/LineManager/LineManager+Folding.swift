import Foundation

extension LineManager {
    public var lastVisibleLine: DocumentLineNode {
        if let span = foldedLineProjection.span(containingRow: lineCount - 1) {
            return line(atRow: span.rows.lowerBound - 1)
        }
        return lastLine
    }

    public func setCollapsedLineRanges(_ ranges: [ClosedRange<Int>]) {
        foldedLineProjection.setRanges(ranges, in: self)
    }

    public func isLineHidden(_ row: Int) -> Bool {
        foldedLineProjection.span(containingRow: row) != nil
    }

    public func nextVisibleLine(after line: DocumentLineNode) -> DocumentLineNode? {
        var row = line.index + 1
        if let span = foldedLineProjection.span(containingRow: row) { row = span.rows.upperBound + 1 }
        return row < lineCount ? self.line(atRow: row) : nil
    }

    public func previousVisibleLine(before line: DocumentLineNode) -> DocumentLineNode? {
        var row = line.index - 1
        if let span = foldedLineProjection.span(containingRow: row) { row = span.rows.lowerBound - 1 }
        return row >= 0 ? self.line(atRow: row) : nil
    }

    public func visibleLine(containingCharacterAt location: Int) -> DocumentLineNode? {
        guard let line = line(containingCharacterAt: location) else {
            return nil
        }
        guard !foldedLineProjection.spans.isEmpty else {
            return line
        }
        if let span = foldedLineProjection.span(containingRow: line.index) {
            return self.line(atRow: span.rows.lowerBound - 1)
        }
        return line
    }

    public func visibleLocation(_ location: Int, movingForward: Bool) -> Int {
        guard !foldedLineProjection.spans.isEmpty else {
            return location
        }
        guard let line = line(containingCharacterAt: location),
              let span = foldedLineProjection.span(containingRow: line.index) else { return location }
        if movingForward, span.rows.upperBound + 1 < lineCount {
            return self.line(atRow: span.rows.upperBound + 1).location
        }
        let anchor = self.line(atRow: span.rows.lowerBound - 1)
        return anchor.location + anchor.data.length
    }
}
