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
        var totalFrameHeight = node.data.frameHeight
        var totalByteCount = node.data.byteCount
        if let leftNode = node.left {
            totalFrameHeight += leftNode.data.totalFrameHeight
            totalByteCount += leftNode.data.nodeTotalByteCount
        }
        if let rightNode = node.right {
            totalFrameHeight += rightNode.data.totalFrameHeight
            totalByteCount += rightNode.data.nodeTotalByteCount
        }
        if totalFrameHeight != node.data.totalFrameHeight || totalByteCount != node.data.nodeTotalByteCount {
            node.data.totalFrameHeight = totalFrameHeight
            node.data.nodeTotalByteCount = totalByteCount
            return true
        } else {
            return false
        }
    }
}
