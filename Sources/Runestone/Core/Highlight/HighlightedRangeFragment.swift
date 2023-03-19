import Foundation

final class HighlightedRangeFragment: Equatable {
    let range: NSRange
    let containsStart: Bool
    let containsEnd: Bool
    let color: MultiPlatformColor
    let cornerRadius: CGFloat

    init(range: NSRange, containsStart: Bool, containsEnd: Bool, color: MultiPlatformColor, cornerRadius: CGFloat) {
        self.range = range
        self.containsStart = containsStart
        self.containsEnd = containsEnd
        self.color = color
        self.cornerRadius = cornerRadius
    }
}

extension HighlightedRangeFragment {
    static func == (lhs: HighlightedRangeFragment, rhs: HighlightedRangeFragment) -> Bool {
        lhs.range == rhs.range
        && lhs.containsStart == rhs.containsStart
        && lhs.containsEnd == rhs.containsEnd
        && lhs.color == rhs.color
        && lhs.cornerRadius == rhs.cornerRadius
    }
}
