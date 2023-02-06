#if os(macOS)
import Foundation

final class SelectionService {
    private let navigationService: NavigationService
    private var previouslySelectedRange: NSRange?

    init(navigationService: NavigationService) {
        self.navigationService = navigationService
    }

    func range(movingFrom currentlySelectedRange: NSRange, by granularity: TextGranularity, inDirection direction: TextDirection) -> NSRange {
        let selectedRange = previouslySelectedRange ?? currentlySelectedRange
        let newSelectedRange = move(selectedRange, by: granularity, inDirection: direction)
        previouslySelectedRange = newSelectedRange
        return newSelectedRange
    }

    func range(movingFrom currentlySelectedRange: NSRange, toBoundary boundary: TextBoundary, inDirection direction: TextDirection) -> NSRange {
        let selectedRange = previouslySelectedRange ?? currentlySelectedRange
        let newSelectedRange = move(selectedRange, toBoundary: boundary, inDirection: direction)
        previouslySelectedRange = newSelectedRange
        return newSelectedRange
    }

    func resetPreviouslySelectedRange() {
        previouslySelectedRange = nil
    }
}

private extension SelectionService {
    private func move(_ range: NSRange, by granularity: TextGranularity, inDirection directon: TextDirection) -> NSRange {
        let offset = directon == .forward ? 1 : -1
        let newUpperBound = navigationService.location(movingFrom: range.upperBound, by: offset, granularity: granularity)
        let lengthDiff = newUpperBound - range.upperBound
        return NSRange(location: range.location, length: range.length + lengthDiff)
    }

    private func move(_ range: NSRange, toBoundary boundary: TextBoundary, inDirection directon: TextDirection) -> NSRange {
        let newUpperBound = navigationService.location(movingFrom: range.upperBound, toBoundary: boundary, inDirection: directon)
        let lengthDiff = newUpperBound - range.upperBound
        return NSRange(location: range.location, length: range.length + lengthDiff)
    }
}
#endif
