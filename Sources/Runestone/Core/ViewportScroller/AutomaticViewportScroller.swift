import Combine
import Foundation

final class AutomaticViewportScroller<LineManagerType: LineManaging> {
    private struct SelectedRangeChange {
        let old: NSRange
        let new: NSRange

        var isLowerBoundDifferent: Bool {
            old.lowerBound != new.lowerBound
        }
        var isUpperBoundDifferent: Bool {
            old.upperBound != new.upperBound
        }

        init(_ current: NSRange) {
            self.old = current
            self.new = current
        }

        init(old: NSRange, new: NSRange) {
            self.old = old
            self.new = new
        }
    }

    var isAutomaticScrollEnabled = true

    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let viewportScroller: ViewportScroller<LineManagerType>
    private var cancellables: Set<AnyCancellable> = []

    init(
        selectedRange: CurrentValueSubject<NSRange, Never>,
        viewportScroller: ViewportScroller<LineManagerType>
    ) {
        self.selectedRange = selectedRange
        self.viewportScroller = viewportScroller
        selectedRange.scan(SelectedRangeChange(selectedRange.value)) { change, selectedRange in
            SelectedRangeChange(old: change.new, new: selectedRange)
        }.sink { [weak self] change in
            self?.scroll(basedOn: change)
        }.store(in: &cancellables)
    }
}

private extension AutomaticViewportScroller {
    private func scroll(basedOn change: SelectedRangeChange) {
        guard isAutomaticScrollEnabled else {
            return
        }
        if change.isLowerBoundDifferent && change.isUpperBoundDifferent {
            viewportScroller.scroll(toVisibleRange: change.new)
        } else if change.isLowerBoundDifferent {
            let range = NSRange(location: change.new.lowerBound, length: 0)
            viewportScroller.scroll(toVisibleRange: range)
        } else if change.isUpperBoundDifferent {
            let range = NSRange(location: change.new.upperBound, length: 0)
            viewportScroller.scroll(toVisibleRange: range)
        }
    }
}
