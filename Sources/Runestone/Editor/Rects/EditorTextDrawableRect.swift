//
//  EditorTextDrawableRect.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A rect suitable for drawing text with Core Text. Coordinates are relative to the screen
// and (0, 0) is placed in the lower-left corner. Furthermore, since the text is drawing
// in a view that doesn't move when scrolling (EditorBackingView), the rect is offset by
// the viewport when converting from a EditorScreenRect
struct EditorTextDrawableRect: RectProtocol {
    var origin: CGPoint
    var size: CGSize

    init(_ rect: CGRect) {
        self.origin = rect.origin
        self.size = rect.size
    }

    init(_ screenRect: EditorScreenRect, viewport: CGRect) {
        let minY = viewport.maxY - screenRect.minY - screenRect.height
        self.origin = CGPoint(x: screenRect.minX, y: minY)
        self.size = CGSize(width: screenRect.width, height: screenRect.height)
    }
}
