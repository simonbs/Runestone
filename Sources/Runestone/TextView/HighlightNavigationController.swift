//
//  HighlightNavigationController.swift
//  
//
//  Created by Simon on 05/10/2021.
//

import Foundation
import UIKit

protocol HighlightNavigationControllerDelegate: AnyObject {
    func highlightNavigationController(
        _ controller: HighlightNavigationController,
        shouldNavigateTo highlightNavigationRange: HighlightNavigationRange)
}

struct HighlightNavigationRange {
    enum LoopMode {
        case none
        case previousGoesToLast
        case nextGoesToFirst
    }

    let range: NSRange
    let loopMode: LoopMode

    init(range: NSRange, loopMode: LoopMode = .none) {
        self.range = range
        self.loopMode = loopMode
    }
}

final class HighlightNavigationController {
    weak var delegate: HighlightNavigationControllerDelegate?
    var selectedRange: NSRange?
    var highlightedRanges: [HighlightedRange] = []

    private var previousNavigationRange: HighlightNavigationRange? {
        if let selectedRange = selectedRange {
            let reversedRanges = highlightedRanges.reversed()
            if let nextRange = reversedRanges.first(where: { $0.range.upperBound <= selectedRange.lowerBound }) {
                return HighlightNavigationRange(range: nextRange.range)
            } else if let firstRange = reversedRanges.first {
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
            } else if let firstRange = highlightedRanges.first {
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
}
