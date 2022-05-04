import UIKit

final class TextSelectionRect: UITextSelectionRect {
    override var rect: CGRect {
        return _rect
    }
    override var writingDirection: NSWritingDirection {
        return _writingDirection
    }
    override var containsStart: Bool {
        return _containsStart
    }
    override var containsEnd: Bool {
        return _containsEnd
    }
    override var isVertical: Bool {
        return _isVertical
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
