//
//  EditorTextRendererPoint.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A point in the text renderer. The point is relative the renderer and (0,0) is placed in the upper-left corner.
struct EditorTextRendererPoint: PointProtocol {
    let point: CGPoint

    init(_ point: CGPoint) {
        self.point = point
    }

    init(_ point: EditorScreenPoint, viewport: CGRect, destinationRenderer: EditorTextRenderer) {
        let rendererFlippedYPosition = viewport.maxY - destinationRenderer.origin.y
        let rendererLocalYPosition = destinationRenderer.preferredSize.height - (rendererFlippedYPosition - point.y)
        let point = CGPoint(x: point.x, y: rendererLocalYPosition)
        self.init(point)
    }
}
