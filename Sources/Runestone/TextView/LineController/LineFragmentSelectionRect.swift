//
//  LineFragmentSelectionRect.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreGraphics
import Foundation

struct LineFragmentSelectionRect {
    let rect: CGRect
    let range: NSRange

    init(rect: CGRect, range: NSRange) {
        self.rect = rect
        self.range = range
    }
}
