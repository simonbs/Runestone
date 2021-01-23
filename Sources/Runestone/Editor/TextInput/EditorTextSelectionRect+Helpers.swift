//
//  EditorTextSelectionRect+Helpers.swift
//  
//
//  Created by Simon Støvring on 14/01/2021.
//

import CoreGraphics

extension Array where Element == EditorTextSelectionRect {
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
            let newElement = Element(rect: newRect, writingDirection: element.writingDirection, containsStart: element.containsStart, containsEnd: element.containsEnd)
            result.append(newElement)
        }
        return result
    }
}
