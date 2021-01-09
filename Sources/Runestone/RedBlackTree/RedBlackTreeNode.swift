//
//  File.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation

final class RedBlackTreeNode<ID: RedBlackTreeNodeID, Value: RedBlackTreeValue, Context> {
    typealias Tree = RedBlackTree<ID, Value, Context>

    enum Color {
        case black
        case red
    }

    let id = ID()
    var value: Value
    var totalNodeValue: Value
    var totalNodeCount: Int
    var left: RedBlackTreeNode?
    var right: RedBlackTreeNode?
    var parent: RedBlackTreeNode?
    var color: Color = .black
    let context: Context
    var index: Int {
        return tree.index(of: self)
    }
    var location: Value {
        return tree.location(of: self)
    }

    private weak var _tree: Tree?
    private var tree: Tree {
        if let tree = _tree {
            return tree
        } else {
            fatalError("Accessing tree after it has been deallocated.")
        }
    }

    init(tree: Tree, value: Value, context: Context) {
        self._tree = tree
        self.totalNodeCount = 1
        self.value = value
        self.totalNodeValue = value
        self.context = context
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
        if let context = context as? CustomDebugStringConvertible {
            return context.debugDescription
        } else {
            return "[Node totalValue=\(value) totalNodeCount=\(totalNodeCount)]"
        }
    }
}
