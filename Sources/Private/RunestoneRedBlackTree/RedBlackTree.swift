// swiftlint:disable file_length
import Foundation

package final class RedBlackTree<NodeValue: RedBlackTreeNodeValue, NodeData> {
    package typealias Node = RedBlackTreeNode<NodeValue, NodeData>

    package let minimumValue: NodeValue
    // swiftlint:disable:next implicitly_unwrapped_optional
    package private(set) var root: Node!
    package var nodeTotalCount: Int {
        root.nodeTotalCount
    }
    package var nodeTotalValue: NodeValue {
        root.nodeTotalValue
    }

    private let childrenUpdater: AnyRedBlackTreeChildrenUpdater<NodeValue, NodeData>

    convenience package init(minimumValue: NodeValue, rootValue: NodeValue, rootData: NodeData) {
        self.init(
            minimumValue: minimumValue,
            rootValue: rootValue,
            rootData: rootData, 
            childrenUpdater: NullObjectRedBlackTreeChildrenUpdater()
        )
    }

    package init<ChildrenUpdater: RedBlackTreeChildrenUpdating>(
        minimumValue: NodeValue,
        rootValue: NodeValue,
        rootData: NodeData,
        childrenUpdater: ChildrenUpdater
    ) where ChildrenUpdater.NodeValue == NodeValue, ChildrenUpdater.NodeData == NodeData {
        self.minimumValue = minimumValue
        self.childrenUpdater = AnyRedBlackTreeChildrenUpdater(
            ParentTraversingRedBlackTreeChildrenUpdater(
                CompositeRedBlackTreeChildrenUpdater([
                    AnyRedBlackTreeChildrenUpdater(TotalValueRedBlackTreeChildrenUpdater()),
                    AnyRedBlackTreeChildrenUpdater(TotalCountRedBlackTreeChildrenUpdater()),
                    AnyRedBlackTreeChildrenUpdater(childrenUpdater)
                ])
            )
        )
        self.root = Node(tree: self, value: rootValue, data: rootData)
        self.root.color = .black
    }

    package func reset(rootValue: NodeValue, rootData: NodeData) {
        root = Node(tree: self, value: rootValue, data: rootData)
    }

    package func rebuild(from nodes: [Node]) {
        assert(!nodes.isEmpty, "Cannot rebuild tree from empty set of nodes")
        let height = getTreeHeight(nodeCount: nodes.count)
        root = buildTree(from: nodes, start: 0, end: nodes.count, subtreeHeight: height)
        root.color = .black
    }

//    func location(of node: Node) -> NodeValue {
//        offset(
//            of: node, valueKeyPath: \.value, 
//            totalValueKeyPath: \.nodeTotalValue, 
//            minimumValue: minimumValue
//        )
//    }

    func index(of node: Node) -> Int {
        var index = node.left?.nodeTotalCount ?? 0
        var workingNode = node
        while let parentNode = workingNode.parent {
            if workingNode === parentNode.right {
                if let leftNode = parentNode.left {
                    index += leftNode.nodeTotalCount
                }
                index += 1
            }
            workingNode = parentNode
        }
        return index
    }

    package func updateAfterChangingChildren(of node: Node) {
        childrenUpdater.updateChildren(of: node)
    }

    package func node(atIndex index: Int) -> Node {
        assert(index >= 0)
        assert(index < root.nodeTotalCount)
        var remainingIndex = index
        var node = root!
        while true {
            if let leftNode = node.left, remainingIndex < leftNode.nodeTotalCount {
                node = leftNode
            } else {
                if let leftNode = node.left {
                    remainingIndex -= leftNode.nodeTotalCount
                }
                if remainingIndex == 0 {
                    return node
                }
                remainingIndex -= 1
                node = node.right!
            }
        }
    }

    @discardableResult
    package func insertNode(value: NodeValue, data: NodeData, after existingNode: Node) -> Node {
        let newNode = Node(tree: self, value: value, data: data)
        insert(newNode, after: existingNode)
        return newNode
    }

    package func remove(_ removedNode: Node) {
        if let removedNodeRight = removedNode.right, removedNode.left != nil {
            let leftMost = removedNodeRight.leftMost
            // Remove leftMost node from its current location
            remove(leftMost)
            // ...and overwrite removedNode with it.
            replace(removedNode, with: leftMost)
            leftMost.left = removedNode.left
            leftMost.left?.parent = leftMost
            leftMost.right = removedNode.right
            leftMost.right?.parent = leftMost
            leftMost.color = removedNode.color
            childrenUpdater.updateChildren(of: leftMost)
            if let leftMostParent = leftMost.parent {
                childrenUpdater.updateChildren(of: leftMostParent)
            }
        } else {
            // Either removedNode.left or removedNode.right is null.
            let parentNode = removedNode.parent
            let childNode = removedNode.left ?? removedNode.right
            replace(removedNode, with: childNode)
            if let parentNode {
                childrenUpdater.updateChildren(of: parentNode)
            }
            if removedNode.color == .black {
                if childNode != nil && childNode?.color == .red {
                    childNode?.color = .black
                } else if let parentNode = parentNode {
                    fixTree(afterDeleting: childNode, parentNode: parentNode)
                }
            }
        }
    }
}

private extension RedBlackTree {
    private func insert(_ newNode: Node, after node: Node) {
        if node.right == nil {
            insert(newNode, asRightChildOf: node)
        } else {
            insert(newNode, asLeftChildOf: node.right!.leftMost)
        }
    }

    private func insert(_ newNode: Node, asLeftChildOf parentNode: Node) {
        assert(parentNode.left == nil)
        parentNode.left = newNode
        newNode.parent = parentNode
        newNode.color = .red
        childrenUpdater.updateChildren(of: parentNode)
        fixTree(afterInserting: newNode)
    }

    private func insert(_ newNode: Node, asRightChildOf parentNode: Node) {
        assert(parentNode.right == nil)
        parentNode.right = newNode
        newNode.parent = parentNode
        newNode.color = .red
        childrenUpdater.updateChildren(of: parentNode)
        fixTree(afterInserting: newNode)
    }

    private func replace(_ replacedNode: Node, with newNode: Node?) {
        if replacedNode.parent == nil {
            assert(replacedNode === root)
            root = newNode!
        } else if replacedNode.parent?.left === replacedNode {
            replacedNode.parent?.left = newNode
        } else {
            replacedNode.parent?.right = newNode
        }
        newNode?.parent = replacedNode.parent
        replacedNode.parent = nil
    }

    private func fixTree(afterInserting newNode: Node) {
        var node = newNode
        assert(node.color == .red)
        assert(node.left == nil || node.left?.color == .black)
        assert(node.right == nil || node.right?.color == .black)
        if var parentNode = node.parent {
            switch parentNode.color {
            case .black:
                // The parent is black so our red node, as ensured by the assert, is placed correctly,
                // since the number of black nodes on the path haven't changed.
                break
            case .red:
                // The parent is red so we have a conflict which we need to resolve.
                // Since the root is always black and the parent to this node is red,
                // we must have a grandparent node.
                var grandparentNode = parentNode.parent!
                if let uncleNode = sibling(to: parentNode), uncleNode.color == .red {
                    parentNode.color = .black
                    uncleNode.color = .black
                    grandparentNode.color = .red
                    fixTree(afterInserting: grandparentNode)
                } else {
                    // We now know that the parent is red and the uncle is black.
                    if node === parentNode.right && parentNode === grandparentNode.left {
                        rotateLeft(parentNode)
                        node = node.left!
                    } else if node === parentNode.left && parentNode === grandparentNode.right {
                        rotateRight(parentNode)
                        node = node.right!
                    }
                    // Nodes might have changed after rotation.
                    parentNode = node.parent!
                    grandparentNode = parentNode.parent!
                    // Recolor nodes.
                    parentNode.color = .black
                    grandparentNode.color = .red
                    // Rotate again.
                    if node === parentNode.left && parentNode === grandparentNode.left {
                        rotateRight(grandparentNode)
                    } else {
                        assert(node === parentNode.right && parentNode === grandparentNode.right)
                        rotateLeft(grandparentNode)
                    }
                }
            }
        } else {
            // We inserted the root node which must be black. Making the root node black increments the number
            // of black nodes on all paths by 1, so all paths still have the same number of black nodes.
            node.color = .black
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func fixTree(afterDeleting node: Node?, parentNode: Node) {
        assert(node == nil || node?.parent === parentNode)
        var sibling = self.sibling(to: node, through: parentNode)
        if sibling?.color == .red {
            parentNode.color = .red
            sibling?.color = .black
            if node === parentNode.left {
                rotateLeft(parentNode)
            } else {
                rotateRight(parentNode)
            }
            // Update sibling after rotation.
            sibling = self.sibling(to: node, through: parentNode)
        }
        if parentNode.color == .black
            && sibling?.color == .black
            && getColor(of: sibling?.left) == .black
            && getColor(of: sibling?.right) == .black {
            sibling?.color = .red
            if let parentNodesParentNode = parentNode.parent {
                fixTree(afterDeleting: parentNode, parentNode: parentNodesParentNode)
            }
        } else if parentNode.color == .red
                    && sibling?.color == .black
                    && getColor(of: sibling?.left) == .black
                    && getColor(of: sibling?.right) == .black {
            sibling?.color = .red
            parentNode.color = .black
        } else {
            if node === parentNode.left
                && sibling?.color == .black
                && getColor(of: sibling?.left) == .red
                && getColor(of: sibling?.right) == .black {
                sibling?.color = .red
                sibling?.left?.color = .black
                if let sibling = sibling {
                    rotateRight(sibling)
                }
            } else if node === parentNode.right
                        && sibling?.color == .black
                        && getColor(of: sibling?.right) == .red
                        && getColor(of: sibling?.left) == .black {
                sibling?.color = .red
                sibling?.right?.color = .black
                if let sibling = sibling {
                    rotateLeft(sibling)
                }
            }
            // Update sibling after rotation.
            sibling = self.sibling(to: node, through: parentNode)
            sibling?.color = parentNode.color
            parentNode.color = .black
            if node === parentNode.left {
                if let rightSibling = sibling?.right {
                    assert(rightSibling.color == .red)
                    rightSibling.color = .black
                }
                rotateLeft(parentNode)
            } else {
                if let leftSibling = sibling?.left {
                    assert(leftSibling.color == .red)
                    leftSibling.color = .black
                }
                rotateRight(parentNode)
            }
        }
    }

    private func rotateLeft(_ p: Node) {
        // Let q be p's right child.
        guard let q = p.right else {
            fatalError("Can't rotate left when p's right-hand side child is nil.")
        }
        assert(q.parent === p)
        // Set q to be the new root.
        replace(p, with: q)
        // Set p's right child to be q's left child.
        p.right = q.left
        p.right?.parent = p
        // Set q's left child to be p.
        q.left = p
        p.parent = q
        childrenUpdater.updateChildren(of: p)
    }

    private func rotateRight(_ p: Node) {
        // Let q be p's left child.
        guard let q = p.left else {
            fatalError("Can't rotate right when p's left-hand side child is nil.")
        }
        assert(q.parent === p)
        // Set q to be the new root.
        replace(p, with: q)
        // Set p's left child to be q's right child.
        p.left = q.right
        p.left?.parent = p
        // Set q's right child to be p.
        q.right = p
        p.parent = q
        childrenUpdater.updateChildren(of: p)
    }

    private func sibling(to node: Node) -> Node? {
        if node === node.parent?.left {
            return node.parent?.right
        } else {
            return node.parent?.left
        }
    }

    private func sibling(to node: Node?, through parentNode: Node) -> Node? {
        assert(node == nil || node?.parent === parentNode)
        if node === parentNode.left {
            return parentNode.right
        } else {
            return parentNode.left
        }
    }

    private func getColor(of node: Node?) -> RedBlackTreeNodeColor {
        node?.color ?? .black
    }

    private func buildTree(from nodes: [Node], start: Int, end: Int, subtreeHeight: Int) -> Node? {
        assert(start <= end)
        if start == end {
            return nil
        }
        let middle = (start + end) / 2
        let node = nodes[middle]
        node.left = buildTree(from: nodes, start: start, end: middle, subtreeHeight: subtreeHeight - 1)
        node.right = buildTree(from: nodes, start: middle + 1, end: end, subtreeHeight: subtreeHeight - 1)
        node.left?.parent = node
        node.right?.parent = node
        if subtreeHeight == 1 {
            node.color = .red
        }
        childrenUpdater.updateChildren(of: node)
        return node
    }

    private func getTreeHeight(nodeCount: Int) -> Int {
        if nodeCount == 0 {
            return 0
        } else {
            return getTreeHeight(nodeCount: nodeCount / 2) + 1
        }
    }
}

extension RedBlackTree: CustomDebugStringConvertible {
    package var debugDescription: String {
        append(root, to: "", indent: 0)
    }

    private func append(_ node: Node, to string: String, indent: Int) -> String {
        var result = string
        switch node.color {
        case .red:
            result += "🔴  "
        case .black:
            result += "⚫️ "
        }
        result += node.debugDescription
        result += "\n"
        if let leftNode = node.left {
            result += String(repeating: " ", count: indent)
            result += "L: "
            result = append(leftNode, to: result, indent: indent + 2)
        }
        if let rightNode = node.right {
            result += String(repeating: " ", count: indent)
            result += "R: "
            result = append(rightNode, to: result, indent: indent + 2)
        }
        return result
    }
}

extension RedBlackTree where NodeData == Void {
    convenience init(minimumValue: NodeValue, rootValue: NodeValue) {
        self.init(
            minimumValue: minimumValue,
            rootValue: rootValue,
            rootData: (),
            childrenUpdater: NullObjectRedBlackTreeChildrenUpdater()
        )
    }

    func reset(rootValue: NodeValue) {
        reset(rootValue: rootValue, rootData: ())
    }

    @discardableResult
    func insertNode(value: NodeValue, after existingNode: Node) -> Node {
        insertNode(value: value, data: (), after: existingNode)
    }
}
