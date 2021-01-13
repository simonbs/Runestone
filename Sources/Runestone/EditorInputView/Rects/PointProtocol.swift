//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

protocol PointProtocol {
    var point: CGPoint { get }
    init(_ point: CGPoint)
}

extension PointProtocol {
    var x: CGFloat {
        return point.x
    }
    var y: CGFloat {
        return point.y
    }

    init(x: CGFloat, y: CGFloat) {
        let point = CGPoint(x: x, y: y)
        self.init(point)
    }
}
