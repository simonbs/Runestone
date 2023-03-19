import Combine
import Foundation

final class HighlightedRangeNavigator {
    var loopingMode: HighlightedRangeLoopingMode = .disabled
    var showMenuAfterNavigatingToHighlightedRange = true

    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let highlightedRanges: CurrentValueSubject<[HighlightedRange], Never>
    private let viewportScroller: ViewportScroller
    private let textViewDelegateBox: TextViewDelegateBox
    private var isLoopingEnabled: Bool {
        loopingMode == .enabled
    }
    private var previousNavigationDestination: HighlightedRangeNavigationDestination? {
        let reversedRanges = highlightedRanges.value.reversed()
        if let nextRange = reversedRanges.first(where: { $0.range.upperBound <= selectedRange.value.lowerBound }) {
            return HighlightedRangeNavigationDestination(range: nextRange.range)
        } else if isLoopingEnabled, let firstRange = reversedRanges.first {
            return HighlightedRangeNavigationDestination(range: firstRange.range, loopMode: .previousGoesToLast)
        } else {
            return nil
        }
    }
    private var nextNavigationDestination: HighlightedRangeNavigationDestination? {
        if let nextRange = highlightedRanges.value.first(where: { $0.range.lowerBound >= selectedRange.value.upperBound }) {
            return HighlightedRangeNavigationDestination(range: nextRange.range)
        } else if isLoopingEnabled, let firstRange = highlightedRanges.value.first {
            return HighlightedRangeNavigationDestination(range: firstRange.range, loopMode: .nextGoesToFirst)
        } else {
            return nil
        }
    }

    init(
        selectedRange: CurrentValueSubject<NSRange, Never>,
        highlightedRanges: CurrentValueSubject<[HighlightedRange], Never>,
        viewportScroller: ViewportScroller,
        textViewDelegateBox: TextViewDelegateBox
    ) {
        self.selectedRange = selectedRange
        self.highlightedRanges = highlightedRanges
        self.viewportScroller = viewportScroller
    }

    func selectPreviousRange() {
        if let previousNavigationDestination {
            navigate(to: previousNavigationDestination)
        }
    }

    func selectNextRange() {
        if let nextNavigationDestination {
            navigate(to: nextNavigationDestination)
        }
    }

    func selectRange(at index: Int) {
        if index >= 0 && index < highlightedRanges.value.count {
            let highlightedRange = highlightedRanges.value[index]
            let destination = HighlightedRangeNavigationDestination(range: highlightedRange.range)
            navigate(to: destination)
        } else {
            let count = highlightedRanges.value.count
            let countString = count == 1 ? "There is \(count) highlighted range" : "There are \(count) highlighted ranges"
            fatalError("Cannot select highlighted range at index \(index). \(countString)")
        }
    }
}

private extension HighlightedRangeNavigator {
    private func navigate(to destination: HighlightedRangeNavigationDestination) {
        viewportScroller.scroll(toVisibleRange: destination.range)
        selectedRange.value = destination.range
        _ = becomeFirstResponder()
        if showMenuAfterNavigatingToHighlightedRange {
            editMenuController.presentEditMenu(from: self, forTextIn: destination.range)
        }
        switch destination.loopMode {
        case .previousGoesToLast:
            textViewDelegateBox.delegate?.textViewDidLoopToLastHighlightedRange(self)
        case .nextGoesToFirst:
            textViewDelegateBox.delegate?.textViewDidLoopToFirstHighlightedRange(self)
        case .disabled:
            break
        }
    }
}
