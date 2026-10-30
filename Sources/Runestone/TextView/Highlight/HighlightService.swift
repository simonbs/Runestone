import Foundation

final class HighlightService {
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                invalidateHighlightedRangeFragments()
            }
        }
    }
    var highlightedRanges: [HighlightedRange] = [] {
        didSet {
            if highlightedRanges != oldValue {
                invalidateHighlightedRangeFragments()
            }
        }
    }

    private var highlightedRangeFragmentsPerLine: [DocumentLineNodeID: [HighlightedRangeFragment]] = [:]
    private var highlightedRangeFragmentsPerLineFragment: [LineFragmentID: [HighlightedRangeFragment]] = [:]

    init(lineManager: LineManager) {
        self.lineManager = lineManager
    }

    func highlightedRangeFragments(for lineFragment: LineFragment, inLineWithID lineID: DocumentLineNodeID) -> [HighlightedRangeFragment] {
        if let lineFragmentHighlightRangeFragments = highlightedRangeFragmentsPerLineFragment[lineFragment.id] {
            return lineFragmentHighlightRangeFragments
        } else {
            let highlightedLineFragments = createHighlightedLineFragments(for: lineFragment, inLineWithID: lineID)
            highlightedRangeFragmentsPerLineFragment[lineFragment.id] = highlightedLineFragments
            return highlightedLineFragments
        }
    }
}

private extension HighlightService {
    private func invalidateHighlightedRangeFragments() {
        highlightedRangeFragmentsPerLine.removeAll()
        highlightedRangeFragmentsPerLineFragment.removeAll()
        highlightedRangeFragmentsPerLine = createHighlightedRangeFragmentsPerLine()
    }

    private func createHighlightedRangeFragmentsPerLine() -> [DocumentLineNodeID: [HighlightedRangeFragment]] {
        var result: [DocumentLineNodeID: [HighlightedRangeFragment]] = [:]
        for highlightedRange in highlightedRanges where highlightedRange.range.length > 0 {
            let lines = lineManager.lines(in: highlightedRange.range)
            for line in lines {
                let lineRange = NSRange(location: line.location, length: line.data.totalLength)
                let source = HighlightRangeSlice(range: highlightedRange.range, containsStart: true, containsEnd: true)
                guard let slice = source.clipped(to: lineRange, localize: true) else {
                    continue
                }
                let highlightedRangeFragment = HighlightedRangeFragment(range: slice.range,
                                                                        containsStart: slice.containsStart,
                                                                        containsEnd: slice.containsEnd,
                                                                        color: highlightedRange.color,
                                                                        cornerRadius: highlightedRange.cornerRadius)
                if let existingHighlightedRangeFragments = result[line.id] {
                    result[line.id] = existingHighlightedRangeFragments + [highlightedRangeFragment]
                } else {
                    result[line.id] = [highlightedRangeFragment]
                }
            }
        }
        return result
    }

    private func createHighlightedLineFragments(for lineFragment: LineFragment,
                                                inLineWithID lineID: DocumentLineNodeID) -> [HighlightedRangeFragment] {
        guard let lineHighlightedRangeFragments = highlightedRangeFragmentsPerLine[lineID] else {
            return []
        }
        return lineHighlightedRangeFragments.compactMap { lineHighlightedRangeFragment in
            let source = HighlightRangeSlice(range: lineHighlightedRangeFragment.range,
                                             containsStart: lineHighlightedRangeFragment.containsStart,
                                             containsEnd: lineHighlightedRangeFragment.containsEnd)
            guard let slice = source.clipped(to: lineFragment.range) else {
                return nil
            }
            return HighlightedRangeFragment(range: slice.range,
                                            containsStart: slice.containsStart,
                                            containsEnd: slice.containsEnd,
                                            color: lineHighlightedRangeFragment.color,
                                            cornerRadius: lineHighlightedRangeFragment.cornerRadius)
        }
    }
}
