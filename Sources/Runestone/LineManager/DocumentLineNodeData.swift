//
//  DocumentLineNodeData.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation
import CoreGraphics

final class DocumentLineNodeData {
    var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    var totalLength: Int = 0
    var length: Int {
        return totalLength - delimiterLength
    }
    var frameHeight: CGFloat
    var totalFrameHeight: CGFloat = 0

    init(frameHeight: CGFloat) {
        self.frameHeight = frameHeight
    }
}
