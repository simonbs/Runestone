//
//  File.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation
import CoreGraphics

final class DocumentLineChildrenUpdater: RedBlackTreeChildrenUpdater<DocumentLineNodeID, Int, DocumentLineNodeData> {
    override func updateAfterChangingChildren(of node: Node) -> Bool {
        var totalValue = node.data.frameHeight
        if let leftNode = node.left {
            totalValue += leftNode.data.totalFrameHeight
        }
        if let rightNode = node.right {
            totalValue += rightNode.data.totalFrameHeight
        }
        if totalValue != node.data.totalFrameHeight {
            node.data.totalFrameHeight = totalValue
            return true
        } else {
            return false
        }
    }
}
