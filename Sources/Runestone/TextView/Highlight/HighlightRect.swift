import UIKit

struct HighlightRect {
    let id: String
    let rect: CGRect
    let containsStart: Bool
    let containsEnd: Bool
    let color: UIColor
    let cornerRadius: CGFloat

    init(highlightedRange: HighlightedRange, selectionRect: TextSelectionRect) {
        self.id = highlightedRange.id
        self.rect = selectionRect.rect
        self.containsStart = selectionRect.containsStart
        self.containsEnd = selectionRect.containsEnd
        self.color = highlightedRange.color
        self.cornerRadius = highlightedRange.cornerRadius
    }
}
