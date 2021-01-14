//
//  EditorTextLayerRect.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A rect in the an EditorTextLayer. The coordinate is relative to the text layer
// and (0,0) is placed in the upper-left corner.
struct EditorTextLayerRect: RectProtocol {
    var origin: CGPoint
    var size: CGSize

    init(_ rect: CGRect) {
        self.origin = rect.origin
        self.size = rect.size
    }
}
