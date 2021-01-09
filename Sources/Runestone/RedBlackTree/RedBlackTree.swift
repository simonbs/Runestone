//
//  File.swift
//  
//
//  Created by Simon Støvring on 09/01/2021.
//

import Foundation

final class RedBlackTree<Context> {
    var totalNodeCount: Int {
        return root.totalNodeCount
    }
    var totalValue: Int {
        return root.totalNodeValue
    }

    private(set) var root: RedBlackTreeNode<Context>!

    init(rootContext: Context) {
        root = RedBlackTreeNode(tree: self, value: 0, context: rootContext)
        root.color = .black
    }

    func reset(rootContext: Context) {
        root = RedBlackTreeNode<Context>(tree: self, value: 0, context: rootContext)
    }

    func node(containingValue value: Int) -> RedBlackTreeNode<Context> {
        assert(value >= 0)
        assert(value <= root.totalNodeValue)
        if value == root.totalNodeValue {
            return root.rightMost
        } else {
            var remainingValue = value
            var node = root!
            while true {
                if let leftNode = node.left, remainingValue < leftNode.totalNodeValue {
                    node = leftNode
                } else {
                    if let leftNode = node.left {
                        remainingValue -= leftNode.totalNodeValue
                    }
                    remainingValue -= node.value
                    if remainingValue < 0 {
                        return node
                    } else {
                        node = node.right!
                    }
                }
            }
        }
    }

    func location(of node: RedBlackTreeNode<Context>) -> Int {
        var location = node.left?.totalNodeValue ?? 0
        var workingNode = node
        while let parentNode = workingNode.parent {
            if workingNode === workingNode.parent?.right {
                if let leftNode = workingNode.parent?.left {
                    location += leftNode.totalNodeValue
                }
                location += parentNode.value
            }
            workingNode = parentNode
        }
        return location
    }

    func index(of node: RedBlackTreeNode<Context>) -> Int {
        var index = node.left?.totalNodeCount ?? 0
        var workingNode = node
        while let parentNode = workingNode.parent {
            if workingNode === parentNode.right {
                if let leftNode = parentNode.left {
                    index += leftNode.totalNodeCount
                }
                index += 1
            }
            workingNode = parentNode
        }
        return index
    }

    func node(atIndex index: Int) -> RedBlackTreeNode<Context> {
        assert(index >= 0)
        assert(index < root.totalNodeCount)
        var remainingIndex = index
        var node = root!
        while true {
            if let leftNode = node.left, remainingIndex < leftNode.totalNodeCount {
                node = leftNode
            } else {
                if let leftNode = node.left {
                    remainingIndex -= leftNode.totalNodeCount
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
    func insertNode(withValue value: Int, context: Context, after existingNode: RedBlackTreeNode<Context>) -> RedBlackTreeNode<Context> {
        let newLine = RedBlackTreeNode<Context>(tree: self, value: value, context: context)
        insert(newLine, after: existingNode)
        return newLine
    }

    func remove(_ removedNode: RedBlackTreeNode<Context>) {
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
            updateAfterChangingChildren(of: leftMost)
            if let leftMostParent = leftMost.parent {
                updateAfterChangingChildren(of: leftMostParent)
            }
        } else {
            // Either removedNode.left or removedNode.right is null.
            let parentNode = removedNode.parent
            let childNode = removedNode.left ?? removedNode.right
            replace(removedNode, with: childNode)
            if let parentNode = parentNode {
                updateAfterChangingChildren(of: parentNode)
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

    func updateAfterChangingChildren(of node: RedBlackTreeNode<Context>) {
        var totalCount = 1
        var totalValue = node.value
        if let leftNode = node.left {
            totalCount += leftNode.totalNodeCount
            totalValue += leftNode.totalNodeValue
        }
        if let rightNode = node.right {
            totalCount += rightNode.totalNodeCount
            totalValue += rightNode.totalNodeValue
        }
        if totalCount != node.totalNodeCount || totalValue != node.totalNodeValue {
            node.totalNodeCount = totalCount
            node.totalNodeValue = totalValue
            if let parent = node.parent {
                updateAfterChangingChildren(of: parent)
            }
        }
    }
}

private extension RedBlackTree {
    private func insert(_ newLine: RedBlackTreeNode<Context>, after node: RedBlackTreeNode<Context>) {
        if node.right == nil {
            insert(newLine, asRightChildOf: node)
        } else {
            insert(newLine, asLeftChildOf: node.right!.leftMost)
        }
    }

    private func insert(_ newNode: RedBlackTreeNode<Context>, asLeftChildOf parentNode: RedBlackTreeNode<Context>) {
        assert(parentNode.left == nil)
        parentNode.left = newNode
        newNode.parent = parentNode
        newNode.color = .red
        updateAfterChangingChildren(of: parentNode)
        fixTree(afterInserting: newNode)
    }

    private func insert(_ newNode: RedBlackTreeNode<Context>, asRightChildOf parentNode: RedBlackTreeNode<Context>) {
        assert(parentNode.right == nil)
        parentNode.right = newNode
        newNode.parent = parentNode
        newNode.color = .red
        updateAfterChangingChildren(of: parentNode)
        fixTree(afterInserting: newNode)
    }

    private func replace(_ replacedNode: RedBlackTreeNode<Context>, with newNode: RedBlackTreeNode<Context>?) {
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

    private func fixTree(afterInserting newLine: RedBlackTreeNode<Context>) {
        var node = newLine
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

    private func fixTree(afterDeleting node: RedBlackTreeNode<Context>?, parentNode: RedBlackTreeNode<Context>) {
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

    private func rotateLeft(_ p: RedBlackTreeNode<Context>) {
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
        updateAfterChangingChildren(of: p)
    }

    private func rotateRight(_ p: RedBlackTreeNode<Context>) {
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
        updateAfterChangingChildren(of: p)
    }

    private func sibling(to node: RedBlackTreeNode<Context>) -> RedBlackTreeNode<Context>? {
        if node === node.parent?.left {
            return node.parent?.right
        } else {
            return node.parent?.left
        }
    }

    private func sibling(to node: RedBlackTreeNode<Context>?, through parentNode: RedBlackTreeNode<Context>) -> RedBlackTreeNode<Context>? {
        assert(node == nil || node?.parent === parentNode)
        if node === parentNode.left {
            return parentNode.right
        } else {
            return parentNode.left
        }
    }

    private func getColor(of node: RedBlackTreeNode<Context>?) -> RedBlackTreeNode<Context>.Color {
        return node?.color ?? .black
    }
}

extension RedBlackTree: CustomDebugStringConvertible {
    var debugDescription: String {
        return append(root, to: "", indent: 0)
    }

    private func append(_ node: RedBlackTreeNode<Context>, to string: String, indent: Int) -> String {
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
