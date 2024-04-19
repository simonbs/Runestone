#if os(macOS)
import AppKit

final class TextSelectionRect {
    let rect: CGRect
    let writingDirection: NSWritingDirection
    let containsStart: Bool
    let containsEnd: Bool
    let isVertical: Bool

    init(
        rect: CGRect, 
        writingDirection: NSWritingDirection,
        containsStart: Bool,
        containsEnd: Bool,
        isVertical: Bool = false
    ) {
        self.rect = rect
        self.writingDirection = writingDirection
        self.containsStart = containsStart
        self.containsEnd = containsEnd
        self.isVertical = isVertical
    }
}
#endif
