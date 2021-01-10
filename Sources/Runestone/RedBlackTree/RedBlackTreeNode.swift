//
//  File.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

final class RedBlackTreeNode {
    enum Color {
        case black
        case red
    }

    let id = UUID()
    var nodeTotalLength: Int
    var nodeTotalCount: Int
    var location: Int {
        return tree.location(of: self)
    }
    var totalLength: Int
    var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    var length: Int {
        return totalLength - delimiterLength
    }
    var index: Int {
        return tree.index(of: self)
    }
    var left: RedBlackTreeNode?
    var right: RedBlackTreeNode?
    var parent: RedBlackTreeNode?
    var color: Color = .black

    private weak var _tree: RedBlackTree?
    private var tree: RedBlackTree {
        if let tree = _tree {
            return tree
        } else {
            fatalError("Accessing tree after it has been deallocated.")
        }
    }

    init(tree: RedBlackTree, totalLength: Int) {
        self._tree = tree
        self.nodeTotalCount = 1
        self.nodeTotalLength = totalLength
        self.totalLength = totalLength
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
        return "[RedBlackTreeNode index=\(index) location=\(location) length=\(length) nodeTotalCount=\(nodeTotalCount)]"
    }
}
