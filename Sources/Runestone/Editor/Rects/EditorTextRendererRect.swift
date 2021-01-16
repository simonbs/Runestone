//
//  EditorTextRendererRect.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A rect in the an EditorTextRendererRect. The coordinate is relative to the text renderer
// and (0,0) is placed in the upper-left corner.
struct EditorTextRendererRect: RectProtocol {
    var origin: CGPoint
    var size: CGSize

    init(_ rect: CGRect) {
        self.origin = rect.origin
        self.size = rect.size
    }
}
