import UIKit

final class TextSelectionRect: UITextSelectionRect {
    override var rect: CGRect {
        _rect
    }
    override var writingDirection: NSWritingDirection {
        _writingDirection
    }
    override var containsStart: Bool {
        _containsStart
    }
    override var containsEnd: Bool {
        _containsEnd
    }
    override var isVertical: Bool {
        _isVertical
    }

    private let _rect: CGRect
    private let _writingDirection: NSWritingDirection
    private let _containsStart: Bool
    private let _containsEnd: Bool
    private let _isVertical: Bool

    init(rect: CGRect, writingDirection: NSWritingDirection, containsStart: Bool, containsEnd: Bool, isVertical: Bool = false) {
        _rect = rect
        _writingDirection = writingDirection
        _containsStart = containsStart
        _containsEnd = containsEnd
        _isVertical = isVertical
    }
}
