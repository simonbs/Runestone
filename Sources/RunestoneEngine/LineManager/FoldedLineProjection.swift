import CoreGraphics

/// Maps logical lines onto the displayed document without measuring or mutating hidden lines.
final class FoldedLineProjection {
    struct Span {
        let rows: ClosedRange<Int>
        let first: DocumentLineNode
        let last: DocumentLineNode
        let heightBefore: CGFloat
        let height: CGFloat
    }

    private(set) var spans: [Span] = []
    var hiddenHeight: CGFloat { spans.last.map { $0.heightBefore + $0.height } ?? 0 }

    func setRanges(_ ranges: [ClosedRange<Int>], in manager: LineManager) {
        var merged: [ClosedRange<Int>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            let start = max(1, range.lowerBound)
            let end = min(manager.lineCount - 1, range.upperBound)
            guard start <= end else { continue }
            if let previous = merged.last, start <= previous.upperBound + 1 {
                merged[merged.count - 1] = previous.lowerBound...max(previous.upperBound, end)
            } else {
                merged.append(start...end)
            }
        }
        spans = []
        var hidden: CGFloat = 0
        for rows in merged {
            let first = manager.line(atRow: rows.lowerBound)
            let last = manager.line(atRow: rows.upperBound)
            let height = last.tree.yPosition(of: last) + last.data.lineHeight - first.tree.yPosition(of: first)
            spans.append(Span(rows: rows, first: first, last: last, heightBefore: hidden, height: height))
            hidden += height
        }
    }

    func span(containingRow row: Int) -> Span? {
        let index = upperBound { $0.rows.lowerBound <= row } - 1
        guard index >= 0, spans[index].rows.contains(row) else {
            return nil
        }
        return spans[index]
    }

    func displayedY(of line: DocumentLineNode) -> CGFloat {
        guard !spans.isEmpty else {
            return line.tree.yPosition(of: line)
        }
        let row = line.index
        let index = upperBound { $0.rows.lowerBound <= row } - 1
        guard index >= 0 else {
            return line.tree.yPosition(of: line)
        }
        let span = spans[index]
        if span.rows.contains(row) {
            return span.first.tree.yPosition(of: span.first) - span.heightBefore
        }
        return line.tree.yPosition(of: line) - span.heightBefore - span.height
    }

    func logicalY(for displayedY: CGFloat) -> CGFloat {
        let index = upperBound { span in
            span.first.tree.yPosition(of: span.first) - span.heightBefore <= displayedY
        } - 1
        guard index >= 0 else {
            return displayedY
        }
        let span = spans[index]
        return displayedY + span.heightBefore + span.height
    }

    private func upperBound(where predicate: (Span) -> Bool) -> Int {
        var lower = 0
        var upper = spans.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if predicate(spans[middle]) { lower = middle + 1 } else { upper = middle }
        }
        return lower
    }
}
