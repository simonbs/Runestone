import UIKit

final class HighlightedRangeFragment: Equatable {
    let range: NSRange
    let containsStart: Bool
    let containsEnd: Bool
    let color: UIColor
    let foregroundColor: UIColor?
    let cornerRadius: CGFloat
    var roundedCorners: UIRectCorner {
        if containsStart && containsEnd {
            return .allCorners
        } else if containsStart {
            return [.topLeft, .bottomLeft]
        } else if containsEnd {
            return [.topRight, .bottomRight]
        } else {
            return []
        }
    }

    init(range: NSRange, containsStart: Bool, containsEnd: Bool, color: UIColor, foregroundColor: UIColor? = nil,
         cornerRadius: CGFloat) {
        self.range = range
        self.containsStart = containsStart
        self.containsEnd = containsEnd
        self.color = color
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }
}

extension HighlightedRangeFragment {
    static func == (lhs: HighlightedRangeFragment, rhs: HighlightedRangeFragment) -> Bool {
        lhs.range == rhs.range
        && lhs.containsStart == rhs.containsStart
        && lhs.containsEnd == rhs.containsEnd
        && lhs.color == rhs.color
        && lhs.foregroundColor == rhs.foregroundColor
        && lhs.cornerRadius == rhs.cornerRadius
    }
}
