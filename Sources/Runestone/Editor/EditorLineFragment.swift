//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

class EditorLineFragment {
    let rect: CGRect
    let usedRect: CGRect
    let textContainer: NSTextContainer
    let glyphRange: NSRange

    init(rect: CGRect, usedRect: CGRect, textContainer: NSTextContainer, glyphRange: NSRange) {
        self.rect = rect
        self.usedRect = usedRect
        self.textContainer = textContainer
        self.glyphRange = glyphRange
    }
}
