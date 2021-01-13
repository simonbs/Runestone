//
//  RectProtocol.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

protocol RectProtocol {
    var rect: CGRect { get }
    init(_ rect: CGRect)
}

extension RectProtocol {
    var origin: CGPoint {
        return rect.origin
    }
    var size: CGSize {
        return rect.size
    }
    var minX: CGFloat {
        return rect.minX
    }
    var minY: CGFloat {
        return rect.minY
    }
    var maxX: CGFloat {
        return rect.maxX
    }
    var maxY: CGFloat {
        return rect.maxY
    }
    var width: CGFloat {
        return rect.width
    }
    var height: CGFloat {
        return rect.height
    }

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        self.init(rect)
    }
}
