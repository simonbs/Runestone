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
    let rect: CGRect

    init(_ rect: CGRect) {
        self.rect = rect
    }

    init(_ rect: EditorTextLayerRect, in line: DocumentLineNode) {
        self.init(rect, inLineStartingAt: line.yPosition)
    }

    init(_ rect: EditorTextLayerRect, inLineStartingAt lineYPosition: CGFloat) {
        self.rect = CGRect(x: rect.minX, y: lineYPosition + rect.minY, width: rect.width, height: rect.height)
    }
}
