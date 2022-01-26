import Foundation
import UIKit

protocol HighlightNavigationControllerDelegate: AnyObject {
    func highlightNavigationController(
        _ controller: HighlightNavigationController,
        shouldNavigateTo highlightNavigationRange: HighlightNavigationRange)
}

struct HighlightNavigationRange {
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

final class HighlightNavigationController {
    weak var delegate: HighlightNavigationControllerDelegate?
    var selectedRange: NSRange?
    var highlightedRanges: [HighlightedRange] = []
    var loopRanges = false

    private var previousNavigationRange: HighlightNavigationRange? {
        if let selectedRange = selectedRange {
            let reversedRanges = highlightedRanges.reversed()
            if let nextRange = reversedRanges.first(where: { $0.range.upperBound <= selectedRange.lowerBound }) {
                return HighlightNavigationRange(range: nextRange.range)
            } else if loopRanges, let firstRange = reversedRanges.first {
                return HighlightNavigationRange(range: firstRange.range, loopMode: .previousGoesToLast)
            } else {
                return nil
            }
        } else if let lastRange = highlightedRanges.last {
            return HighlightNavigationRange(range: lastRange.range)
        } else {
            return nil
        }
    }
    private var nextNavigationRange: HighlightNavigationRange? {
        if let selectedRange = selectedRange {
            if let nextRange = highlightedRanges.first(where: { $0.range.lowerBound >= selectedRange.upperBound }) {
                return HighlightNavigationRange(range: nextRange.range)
            } else if loopRanges, let firstRange = highlightedRanges.first {
                return HighlightNavigationRange(range: firstRange.range, loopMode: .nextGoesToFirst)
            } else {
                return nil
            }
        } else if let firstRange = highlightedRanges.first {
            return HighlightNavigationRange(range: firstRange.range)
        } else {
            return nil
        }
    }

    func selectPreviousRange() {
        if let previousNavigationRange = previousNavigationRange {
            selectedRange = previousNavigationRange.range
            delegate?.highlightNavigationController(self, shouldNavigateTo: previousNavigationRange)
        }
    }

    func selectNextRange() {
        if let nextNavigationRange = nextNavigationRange {
            selectedRange = nextNavigationRange.range
            delegate?.highlightNavigationController(self, shouldNavigateTo: nextNavigationRange)
        }
    }

    func selectRange(at index: Int) {
        if index >= 0 && index < highlightedRanges.count {
            let highlightedRange = highlightedRanges[index]
            let navigationRange = HighlightNavigationRange(range: highlightedRange.range)
            selectedRange = highlightedRange.range
            delegate?.highlightNavigationController(self, shouldNavigateTo: navigationRange)
        } else {
            let count = highlightedRanges.count
            let countString = count == 1 ? "There is \(count) highlighted range" : "There are \(count) highlighted ranges"
            fatalError("Cannot select highlighted range at index \(index). \(countString)")
        }
    }
}
