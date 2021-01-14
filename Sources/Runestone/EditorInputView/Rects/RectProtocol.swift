//
//  RectProtocol.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

protocol RectProtocol {
    var origin: CGPoint { get set }
    var size: CGSize { get set }
    init(_ rect: CGRect)
}

extension RectProtocol {
    var origin: CGPoint {
        return origin
    }
    var size: CGSize {
        return size
    }
    var minX: CGFloat {
        return origin.x
    }
    var minY: CGFloat {
        return origin.y
    }
    var maxX: CGFloat {
        return origin.x + size.width
    }
    var maxY: CGFloat {
        return origin.y + size.height
    }
    var width: CGFloat {
        return size.width
    }
    var height: CGFloat {
        return size.height
    }
    var rect: CGRect {
        return CGRect(origin: origin, size: size)
    }

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        self.init(rect)
    }
}
