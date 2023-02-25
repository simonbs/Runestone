import Foundation

protocol HighlightedRangeNavigationControllerDelegate: AnyObject {
    func highlightNavigationController(
        _ controller: HighlightedRangeNavigationController,
        shouldNavigateTo destination: HighlightedRangeNavigationDestination
    )
}

struct HighlightedRangeNavigationDestination {
    enum LoopMode {
        case disabled
        case previousGoesToLast
        case nextGoesToFirst
    }

    let range: NSRange
    let loopMode: LoopMode

    init(range: NSRange, loopMode: LoopMode = .disabled) {
        self.range = range
        self.loopMode = loopMode
    }
}

final class HighlightedRangeNavigationController {
    weak var delegate: HighlightedRangeNavigationControllerDelegate?
    var selectedRange: NSRange?
    var highlightedRanges: [HighlightedRange] = []
    var loopRanges = false

    private var previousNavigationDestination: HighlightedRangeNavigationDestination? {
        if let selectedRange = selectedRange {
            let reversedRanges = highlightedRanges.reversed()
            if let nextRange = reversedRanges.first(where: { $0.range.upperBound <= selectedRange.lowerBound }) {
                return HighlightedRangeNavigationDestination(range: nextRange.range)
            } else if loopRanges, let firstRange = reversedRanges.first {
                return HighlightedRangeNavigationDestination(range: firstRange.range, loopMode: .previousGoesToLast)
            } else {
                return nil
            }
        } else if let lastRange = highlightedRanges.last {
            return HighlightedRangeNavigationDestination(range: lastRange.range)
        } else {
            return nil
        }
    }
    private var nextNavigationDestination: HighlightedRangeNavigationDestination? {
        if let selectedRange = selectedRange {
            if let nextRange = highlightedRanges.first(where: { $0.range.lowerBound >= selectedRange.upperBound }) {
                return HighlightedRangeNavigationDestination(range: nextRange.range)
            } else if loopRanges, let firstRange = highlightedRanges.first {
                return HighlightedRangeNavigationDestination(range: firstRange.range, loopMode: .nextGoesToFirst)
            } else {
                return nil
            }
        } else if let firstRange = highlightedRanges.first {
            return HighlightedRangeNavigationDestination(range: firstRange.range)
        } else {
            return nil
        }
    }

    func selectPreviousRange() {
        if let previousNavigationDestination {
            selectedRange = previousNavigationDestination.range
            delegate?.highlightNavigationController(self, shouldNavigateTo: previousNavigationDestination)
        }
    }

    func selectNextRange() {
        if let nextNavigationDestination {
            selectedRange = nextNavigationDestination.range
            delegate?.highlightNavigationController(self, shouldNavigateTo: nextNavigationDestination)
        }
    }

    func selectRange(at index: Int) {
        if index >= 0 && index < highlightedRanges.count {
            let highlightedRange = highlightedRanges[index]
            let destination = HighlightedRangeNavigationDestination(range: highlightedRange.range)
            selectedRange = highlightedRange.range
            delegate?.highlightNavigationController(self, shouldNavigateTo: destination)
        } else {
            let count = highlightedRanges.count
            let countString = count == 1 ? "There is \(count) highlighted range" : "There are \(count) highlighted ranges"
            fatalError("Cannot select highlighted range at index \(index). \(countString)")
        }
    }
}
