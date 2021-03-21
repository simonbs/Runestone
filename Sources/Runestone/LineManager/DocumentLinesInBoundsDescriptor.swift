//
//  DocumentLinesInBoundsDescriptor.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation
import CoreGraphics

final class DocumentLinesInBoundsSearchQuery: RedBlackTreeSearchQuery {
    private let bounds: CGRect
    private var cachedNodeYPositions: [NodeID: CGFloat] = [:]

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    func shouldTraverseLeftChildren(of node: DocumentLineNode) -> Bool {
        return yPosition(of: node) > bounds.minY
    }

    func shouldTraverseRightChildren(of node: DocumentLineNode) -> Bool {
        return yPosition(of: node) + node.data.lineHeight < bounds.maxY
    }

    func shouldInclude(_ node: DocumentLineNode) -> Bool {
        let nodeLowerBound = yPosition(of: node)
        let nodeUpperBound = nodeLowerBound + node.data.lineHeight
        return nodeLowerBound <= bounds.maxY && bounds.minY <= nodeUpperBound
    }
}

private extension DocumentLinesInBoundsSearchQuery {
    private func yPosition(of node: DocumentLineNode) -> CGFloat {
        if let cachedYPosition = cachedNodeYPositions[node.id] {
            return cachedYPosition
        } else {
            let yPosition = node.yPosition
            cachedNodeYPositions[node.id] = yPosition
            return yPosition
        }
    }
}
