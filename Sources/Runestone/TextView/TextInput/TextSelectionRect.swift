//
//  TextSelectionRect.swift
//  
//
//  Created by Simon Støvring on 07/01/2021.
//

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

extension Array where Element == TextSelectionRect {
    // Ensures that the array of rectangles are all properly aligned on the Y-axis
    // so there's no distance between the rectangles and they don't overlap.
    func ensuringYAxisAlignment() -> [Element] {
        guard count > 1 else {
            return self
        }
        var result: [Element] = [self[0]]
        for idx in 1 ..< count {
            let previousMaxYPosition = self[idx - 1].rect.maxY
            let element = self[idx]
            let yPosition = element.rect.minY
            let distanceDiff = yPosition - previousMaxYPosition
            let newYPosition = yPosition - distanceDiff
            let newHeight = element.rect.height + distanceDiff
            let newRect = CGRect(x: element.rect.minX, y: newYPosition, width: element.rect.width, height: newHeight)
            let newElement = Element(
                rect: newRect,
                writingDirection: element.writingDirection,
                containsStart: element.containsStart,
                containsEnd: element.containsEnd)
            result.append(newElement)
        }
        return result
    }
}
