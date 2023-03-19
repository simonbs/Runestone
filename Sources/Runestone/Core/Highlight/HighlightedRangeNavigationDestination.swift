import Foundation

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
