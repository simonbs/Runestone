//
//  EditorTextLayerPoint.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import CoreGraphics

// A point in the text layer. The point is relative the layer
// and (0,0) is placed in the upper-left corner.
struct EditorTextLayerPoint: PointProtocol {
    let point: CGPoint

    init(_ point: CGPoint) {
        self.point = point
    }

    init(_ point: EditorScreenPoint, viewport: CGRect, destinationLayer: EditorTextLayer) {
        let layerFlippedYPosition = viewport.maxY - destinationLayer.origin.y
        let layerLocalYPosition = destinationLayer.preferredSize.height - (layerFlippedYPosition - point.y)
        let point = CGPoint(x: point.x, y: layerLocalYPosition)
        self.init(point)
    }
}
