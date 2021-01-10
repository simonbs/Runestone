//
//  RedBlackTreeNode.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

protocol RedBlackTreeNodeID: Identifiable & Hashable {
    init()
}

typealias RedBlackTreeNodeValue = Comparable & AdditiveArithmetic

final class RedBlackTreeNode<NodeID: RedBlackTreeNodeID, NodeValue: RedBlackTreeNodeValue, NodeData> {
    typealias Tree = RedBlackTree<NodeID, NodeValue, NodeData>

    let id = NodeID()
    var nodeTotalValue: NodeValue
    var nodeTotalCount: Int
    var location: NodeValue {
        return tree.location(of: self)
    }
    var value: NodeValue
    var index: Int {
        return tree.index(of: self)
    }
    var left: RedBlackTreeNode?
    var right: RedBlackTreeNode?
    var parent: RedBlackTreeNode?
    var color: RedBlackTreeNodeColor = .black
    let data: NodeData
    var tree: Tree {
        if let tree = _tree {
            return tree
        } else {
            fatalError("Accessing tree after it has been deallocated.")
        }
    }
    
    private weak var _tree: Tree?

    init(tree: Tree, value: NodeValue, data: NodeData) {
        self._tree = tree
        self.nodeTotalCount = 1
        self.nodeTotalValue = value
        self.value = value
        self.data = data
    }
}

extension RedBlackTreeNode {
    var leftMost: RedBlackTreeNode {
        var node = self
        while let newNode = node.left {
            node = newNode
        }
        return node
    }
    var rightMost: RedBlackTreeNode {
        var node = self
        while let newNode = node.right {
            node = newNode
        }
        return node
    }
    var previous: RedBlackTreeNode {
        if let left = left {
            return left.rightMost
        } else {
            var oldNode = self
            var node = parent ?? self
            while let parent = node.parent, node.left === oldNode {
                oldNode = node
                node = parent
            }
            return node
        }
    }
    var next: RedBlackTreeNode {
        if let right = right {
            return right.leftMost
        } else {
            var oldNode = self
            var node = parent ?? self
            while let parent = node.parent, node.right === oldNode {
                oldNode = node
                node = parent
            }
            return node
        }
    }
}

extension RedBlackTreeNode: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[RedBlackTreeNode index=\(index) location=\(location) nodeTotalCount=\(nodeTotalCount)]"
    }
}
