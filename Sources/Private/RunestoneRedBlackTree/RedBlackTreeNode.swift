import Foundation

package typealias RedBlackTreeNodeValue = Comparable & AdditiveArithmetic

package final class RedBlackTreeNode<NodeValue: RedBlackTreeNodeValue, NodeData> {
    package typealias Tree = RedBlackTree<NodeValue, NodeData>

    package let id = RedBlackTreeNodeID()
    package var value: NodeValue
    package internal(set) var nodeTotalValue: NodeValue
    package internal(set) var nodeTotalCount: Int
    package internal(set) var left: RedBlackTreeNode?
    package internal(set) var right: RedBlackTreeNode?
    package var data: NodeData
    package var tree: Tree {
        if let tree = _tree {
            return tree
        } else {
            fatalError("Accessing tree after it has been deallocated.")
        }
    }
    package var offset: NodeValue {
        let query = ValueOffsetFromRedBlackTreeNodeQuery(targetNode: self, minimumValue: tree.minimumValue)
        let querier = OffsetFromRedBlackTreeNodeQuerier(querying: tree)
        return querier.offset(for: query)!
    }
    package var index: Int {
        tree.index(of: self)
    }
    
    var color: RedBlackTreeNodeColor = .black
    weak var parent: RedBlackTreeNode?

    private weak var _tree: Tree?

    package init(tree: Tree, value: NodeValue, data: NodeData) {
        self._tree = tree
        self.nodeTotalCount = 1
        self.nodeTotalValue = value
        self.value = value
        self.data = data
    }
}

extension RedBlackTreeNode {
    package var leftMost: RedBlackTreeNode {
        var node = self
        while let newNode = node.left {
            node = newNode
        }
        return node
    }
    package var rightMost: RedBlackTreeNode {
        var node = self
        while let newNode = node.right {
            node = newNode
        }
        return node
    }
    package var previous: RedBlackTreeNode {
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
    package var next: RedBlackTreeNode {
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

extension RedBlackTreeNode: Hashable {
    package static func == (
        lhs: RedBlackTreeNode<NodeValue, NodeData>,
        rhs: RedBlackTreeNode<NodeValue, NodeData>
    ) -> Bool {
        lhs.id == rhs.id
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension RedBlackTreeNode where NodeData == Void {
    convenience init(tree: Tree, value: NodeValue) {
        self.init(tree: tree, value: value, data: ())
    }
}

extension RedBlackTreeNode: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[RedBlackTreeNode index=\(index) offset=\(offset) nodeTotalCount=\(nodeTotalCount)]"
    }
}
