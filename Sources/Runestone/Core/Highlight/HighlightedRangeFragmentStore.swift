import Combine
import Foundation

final class HighlightedRangeFragmentStore {
    let highlightedRanges = CurrentValueSubject<[HighlightedRange], Never>([])

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private var lineMap: [LineNodeID: [HighlightedRangeFragment]] = [:]
    private var lineFragmentMap: [LineFragmentID: [HighlightedRangeFragment]] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        Publishers.CombineLatest3(stringView, lineManager, highlightedRanges).sink { [weak self] _, _, _ in
            self?.invalidate()
        }.store(in: &cancellables)
    }

    func highlightedRangeFragments(for lineFragment: LineFragment, inLineWithID lineID: LineNodeID) -> [HighlightedRangeFragment] {
        if let highlightedRangeFragments = lineFragmentMap[lineFragment.id] {
            return highlightedRangeFragments
        } else {
            let highlightedRangeFragments = createHighlightedRangeFragments(for: lineFragment, inLineWithID: lineID)
            lineFragmentMap[lineFragment.id] = highlightedRangeFragments
            return highlightedRangeFragments
        }
    }
}

private extension HighlightedRangeFragmentStore {
    private func invalidate() {
        lineMap.removeAll()
        lineFragmentMap.removeAll()
        lineMap = createHighlightedRangeFragmentsPerLine()
    }

    private func createHighlightedRangeFragmentsPerLine() -> [LineNodeID: [HighlightedRangeFragment]] {
        var result: [LineNodeID: [HighlightedRangeFragment]] = [:]
        for highlightedRange in highlightedRanges.value where highlightedRange.range.length > 0 {
            let lines = lineManager.value.lines(in: highlightedRange.range)
            for line in lines {
                let lineRange = NSRange(location: line.location, length: line.data.totalLength)
                guard highlightedRange.range.overlaps(lineRange) else {
                    continue
                }
                let cappedRange = highlightedRange.range.capped(to: lineRange)
                let cappedLocalRange = cappedRange.local(to: lineRange)
                let containsStart = cappedRange.lowerBound == highlightedRange.range.lowerBound
                let containsEnd = cappedRange.upperBound == highlightedRange.range.upperBound
                let highlightedRangeFragment = HighlightedRangeFragment(
                    range: cappedLocalRange,
                    containsStart: containsStart,
                    containsEnd: containsEnd,
                    color: highlightedRange.color,
                    cornerRadius: highlightedRange.cornerRadius
                )
                if let existingHighlightedRangeFragments = result[line.id] {
                    result[line.id] = existingHighlightedRangeFragments + [highlightedRangeFragment]
                } else {
                    result[line.id] = [highlightedRangeFragment]
                }
            }
        }
        return result
    }

    private func createHighlightedRangeFragments(
        for lineFragment: LineFragment,
        inLineWithID lineID: LineNodeID
    ) -> [HighlightedRangeFragment] {
        guard let highlightedRangeFragments = lineMap[lineID] else {
            return []
        }
        return highlightedRangeFragments.compactMap { highlightedRangeFragment in
            guard highlightedRangeFragment.range.overlaps(lineFragment.range) else {
                return nil
            }
            let cappedRange = highlightedRangeFragment.range.capped(to: lineFragment.range)
            let containsStart = highlightedRangeFragment.containsStart && cappedRange.lowerBound == highlightedRangeFragment.range.lowerBound
            let containsEnd = highlightedRangeFragment.containsEnd && cappedRange.upperBound == highlightedRangeFragment.range.upperBound
            return HighlightedRangeFragment(
                range: cappedRange,
                containsStart: containsStart,
                containsEnd: containsEnd,
                color: highlightedRangeFragment.color,
                cornerRadius: highlightedRangeFragment.cornerRadius
            )
        }
    }
}
