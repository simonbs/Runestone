//
//  EditorScreenPoint.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A point on the screen. The point is relative the screen
// and (0,0) is placed in the upper-left corner.
struct EditorScreenPoint: PointProtocol {
    let point: CGPoint

    init(_ point: CGPoint) {
        self.point = point
    }
}
