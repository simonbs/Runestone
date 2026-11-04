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
                selectedSearchResultRange = highlightedRanges.first { highlightedRange in
                    highlightedRange.presentationRole == .selectedSearchResult
                }?.range
                if hasUnchangedRangeGeometry(comparedTo: oldValue) {
                    updateHighlightedRangeFragments(changedFrom: oldValue)
                } else {
                    invalidateHighlightedRangeFragments()
                }
            }
        }
    }
    var isFindResultPresentationActive = false {
        didSet {
            if isFindResultPresentationActive != oldValue {
                invalidateHighlightedRangeFragments()
            }
        }
    }

    private var highlightedRangeFragmentsPerLine: [DocumentLineNodeID: [HighlightedRangeFragment]] = [:]
    private var highlightedRangeFragmentsPerLineFragment: [LineFragmentID: [HighlightedRangeFragment]] = [:]
    private var selectedSearchResultRange: NSRange?

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

    func hiddenTextRanges(for lineFragment: LineFragment, inLineRange lineRange: NSRange) -> [NSRange] {
        guard isFindResultPresentationActive, let selectedRange = selectedSearchResultRange else {
            return []
        }
        let intersection = NSIntersectionRange(selectedRange, lineRange)
        guard intersection.length > 0 else {
            return []
        }
        let localRange = intersection.local(to: lineRange)
        let fragmentIntersection = NSIntersectionRange(localRange, lineFragment.visibleRange)
        return fragmentIntersection.length > 0 ? [fragmentIntersection] : []
    }
}

private extension HighlightService {
    private func hasUnchangedRangeGeometry(comparedTo oldRanges: [HighlightedRange]) -> Bool {
        highlightedRanges.count == oldRanges.count
            && zip(highlightedRanges, oldRanges).allSatisfy { $0.range == $1.range }
    }

    private func updateHighlightedRangeFragments(changedFrom oldRanges: [HighlightedRange]) {
        let changedRanges = zip(highlightedRanges, oldRanges).compactMap { newRange, oldRange in
            newRange == oldRange ? nil : newRange.range
        }
        let affectedLines = Dictionary(changedRanges
            .flatMap(lineManager.lines(in:))
            .map { ($0.id, $0) }) { first, _ in first }
        guard !affectedLines.isEmpty else {
            return
        }
        highlightedRangeFragmentsPerLineFragment.removeAll()
        for line in affectedLines.values {
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            highlightedRangeFragmentsPerLine[line.id] = highlightedRanges.compactMap { highlightedRange in
                guard shouldRender(highlightedRange), highlightedRange.range.overlaps(lineRange) else {
                    return nil
                }
                return makeHighlightedRangeFragment(for: highlightedRange, in: lineRange)
            }
        }
    }

    private func invalidateHighlightedRangeFragments() {
        highlightedRangeFragmentsPerLine.removeAll()
        highlightedRangeFragmentsPerLineFragment.removeAll()
        highlightedRangeFragmentsPerLine = createHighlightedRangeFragmentsPerLine()
    }

    private func createHighlightedRangeFragmentsPerLine() -> [DocumentLineNodeID: [HighlightedRangeFragment]] {
        var result: [DocumentLineNodeID: [HighlightedRangeFragment]] = [:]
        for highlightedRange in highlightedRanges where shouldRender(highlightedRange) {
            let lines = lineManager.lines(in: highlightedRange.range)
            for line in lines {
                let lineRange = NSRange(location: line.location, length: line.data.totalLength)
                guard highlightedRange.range.overlaps(lineRange) else {
                    continue
                }
                let highlightedRangeFragment = makeHighlightedRangeFragment(for: highlightedRange, in: lineRange)
                if let existingHighlightedRangeFragments = result[line.id] {
                    result[line.id] = existingHighlightedRangeFragments + [highlightedRangeFragment]
                } else {
                    result[line.id] = [highlightedRangeFragment]
                }
            }
        }
        return result
    }

    private func makeHighlightedRangeFragment(for highlightedRange: HighlightedRange,
                                              in lineRange: NSRange) -> HighlightedRangeFragment {
        let cappedRange = highlightedRange.range.capped(to: lineRange)
        return HighlightedRangeFragment(range: cappedRange.local(to: lineRange),
                                        containsStart: cappedRange.lowerBound == highlightedRange.range.lowerBound,
                                        containsEnd: cappedRange.upperBound == highlightedRange.range.upperBound,
                                        color: highlightedRange.color,
                                        foregroundColor: highlightedRange.foregroundColor,
                                        cornerRadius: highlightedRange.cornerRadius)
    }

    private func shouldRender(_ highlightedRange: HighlightedRange) -> Bool {
        highlightedRange.range.length > 0
            && (!isFindResultPresentationActive || highlightedRange.presentationRole != .selectedSearchResult)
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
                                            foregroundColor: lineHighlightedRangeFragment.foregroundColor,
                                            cornerRadius: lineHighlightedRangeFragment.cornerRadius)
        }
    }
}
