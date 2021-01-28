//
//  RedBlackTreeChildrenUpdater.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

class RedBlackTreeChildrenUpdater<NodeID: RedBlackTreeNodeID, NodeValue: RedBlackTreeNodeValue, NodeData> {
    typealias Node = RedBlackTreeNode<NodeID, NodeValue, NodeData>

    func updateAfterChangingChildren(of node: Node) -> Bool {
        return false
    }
}
