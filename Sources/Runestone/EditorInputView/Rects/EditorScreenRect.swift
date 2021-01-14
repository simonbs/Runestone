//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A rect on the screen. Coordinates are relative to the screen
// and (0, 0) is placed in the upper-left corner.
struct EditorScreenRect: RectProtocol {
    var origin: CGPoint
    var size: CGSize

    init(_ rect: CGRect) {
        self.origin = rect.origin
        self.size = rect.size
    }

    init(_ rect: EditorTextLayerRect, in line: DocumentLineNode) {
        self.init(rect, inLineStartingAt: line.yPosition)
    }

    init(_ rect: EditorTextLayerRect, inLineStartingAt lineYPosition: CGFloat) {
        self.origin = CGPoint(x: rect.minX, y: lineYPosition + rect.minY)
        self.size = CGSize(width: rect.width, height: rect.height)
    }
}
