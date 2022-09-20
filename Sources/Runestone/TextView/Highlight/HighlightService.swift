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
                guard highlightedRange.range.overlaps(lineRange) else {
                    continue
                }
                let cappedRange = highlightedRange.range.capped(to: lineRange)
                let cappedLocalRange = cappedRange.local(to: lineRange)
                let containsStart = cappedRange.lowerBound == highlightedRange.range.lowerBound
                let containsEnd = cappedRange.upperBound == highlightedRange.range.upperBound
                let highlightedRangeFragment = HighlightedRangeFragment(range: cappedLocalRange,
                                                                        containsStart: containsStart,
                                                                        containsEnd: containsEnd,
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
            guard lineHighlightedRangeFragment.range.overlaps(lineFragment.range) else {
                return nil
            }
            let cappedRange = lineHighlightedRangeFragment.range.capped(to: lineFragment.range)
            let containsStart = lineHighlightedRangeFragment.containsStart && cappedRange.lowerBound == lineHighlightedRangeFragment.range.lowerBound
            let containsEnd = lineHighlightedRangeFragment.containsEnd && cappedRange.upperBound == lineHighlightedRangeFragment.range.upperBound
            return HighlightedRangeFragment(range: cappedRange,
                                            containsStart: containsStart,
                                            containsEnd: containsEnd,
                                            color: lineHighlightedRangeFragment.color,
                                            cornerRadius: lineHighlightedRangeFragment.cornerRadius)
        }
    }
}
