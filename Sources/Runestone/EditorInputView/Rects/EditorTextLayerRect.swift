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
    let rect: CGRect

    init(_ rect: CGRect) {
        self.rect = rect
    }
}
