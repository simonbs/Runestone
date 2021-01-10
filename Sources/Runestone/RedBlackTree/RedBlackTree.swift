//
//  File.swift
//  
//
//  Created by Simon Støvring on 10/01/2021.
//

import Foundation

final class RedBlackTree {
    private enum Side {
        case left
        case right
    }

    var nodeTotalCount: Int {
        return root.nodeTotalCount
    }
    var nodeTotalLength: Int {
        return root.nodeTotalLength
    }

    private(set) lazy var root = RedBlackTreeNode(tree: self, totalLength: 0)

    init() {
        root.color = .black
    }

    func reset() {
        root = RedBlackTreeNode(tree: self, totalLength: 0)
    }

    func node(containgLocation location: Int) -> RedBlackTreeNode {
        assert(location >= 0)
        assert(location <= root.nodeTotalLength)
        if location == root.nodeTotalLength {
            return root.rightMost
        } else {
            var remainingLocation = location
            var node = root
            while true {
                if let leftNode = node.left, remainingLocation < leftNode.nodeTotalLength {
                    node = leftNode
                } else {
                    if let leftNode = node.left {
                        remainingLocation -= leftNode.nodeTotalLength
                    }
                    remainingLocation -= node.totalLength
                    if remainingLocation < 0 {
                        return node
                    } else {
                        node = node.right!
                    }
                }
            }
        }
    }

    func nodePosition(at location: Int) -> LinePosition? {
        guard location >= 0 && location <= root.nodeTotalLength else {
            return nil
        }
        if location == root.nodeTotalLength {
            let node = root.rightMost
            let nodeStartLocation = root.nodeTotalLength - node.nodeTotalLength
            let column = location - nodeStartLocation
            return LinePosition(
                lineStartLocation: nodeStartLocation,
                lineNumber: node.index,
                column: column,
                length: node.length,
                delimiterLength: node.delimiterLength)
        } else {
            var nodeStartLocation = 0
            var remainingLocation = location
            var node = root
            while true {
                if let leftNode = node.left, remainingLocation < leftNode.nodeTotalLength {
                    node = leftNode
                } else {
                    if let leftNode = node.left {
                        nodeStartLocation += leftNode.nodeTotalLength
                        remainingLocation -= leftNode.nodeTotalLength
                    }
                    nodeStartLocation += node.totalLength
                    remainingLocation -= node.totalLength
                    if remainingLocation < 0 {
                        nodeStartLocation -= node.totalLength
                        let column = location - nodeStartLocation
                        return LinePosition(
                            lineStartLocation: nodeStartLocation,
                            lineNumber: node.index,
                            column: column,
                            length: node.length,
                            delimiterLength: node.delimiterLength)
                    } else {
                        node = node.right!
                    }
                }
            }
        }
    }

    func location(of node: RedBlackTreeNode) -> Int {
        var location = node.left?.nodeTotalLength ?? 0
        var workingNode = node
        while let parentNode = workingNode.parent {
            if workingNode === workingNode.parent?.right {
                if let leftNode = workingNode.parent?.left {
                    location += leftNode.nodeTotalLength
                }
                location += parentNode.totalLength
            }
            workingNode = parentNode
        }
        return location
    }

    func index(of node: RedBlackTreeNode) -> Int {
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

    func node(atIndex index: Int) -> RedBlackTreeNode {
        assert(index >= 0)
        assert(index < root.nodeTotalCount)
        var remainingIndex = index
        var node = root
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
    func insertNode(ofLength length: Int, after existingNode: RedBlackTreeNode) -> RedBlackTreeNode {
        let newNode = RedBlackTreeNode(tree: self, totalLength: length)
        insert(newNode, after: existingNode)
        return newNode
    }

    func remove(_ removedNode: RedBlackTreeNode) {
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

    func updateAfterChangingChildren(of node: RedBlackTreeNode) {
        var totalCount = 1
        var totalLength = node.totalLength
        if let leftNode = node.left {
            totalCount += leftNode.nodeTotalCount
            totalLength += leftNode.nodeTotalLength
        }
        if let rightNode = node.right {
            totalCount += rightNode.nodeTotalCount
            totalLength += rightNode.nodeTotalLength
        }
        if totalCount != node.nodeTotalCount || totalLength != node.nodeTotalLength {
            node.nodeTotalCount = totalCount
            node.nodeTotalLength = totalLength
            if let parent = node.parent {
                updateAfterChangingChildren(of: parent)
            }
        }
    }
}

private extension RedBlackTree {
    private func insert(_ newNode: RedBlackTreeNode, after node: RedBlackTreeNode) {
        if node.right == nil {
            insert(newNode, asRightChildOf: node)
        } else {
            insert(newNode, asLeftChildOf: node.right!.leftMost)
        }
    }

    private func insert(_ newNode: RedBlackTreeNode, asLeftChildOf parentNode: RedBlackTreeNode) {
        assert(parentNode.left == nil)
        parentNode.left = newNode
        newNode.parent = parentNode
        newNode.color = .red
        updateAfterChangingChildren(of: parentNode)
        fixTree(afterInserting: newNode)
    }

    private func insert(_ newNode: RedBlackTreeNode, asRightChildOf parentNode: RedBlackTreeNode) {
        assert(parentNode.right == nil)
        parentNode.right = newNode
        newNode.parent = parentNode
        newNode.color = .red
        updateAfterChangingChildren(of: parentNode)
        fixTree(afterInserting: newNode)
    }

    private func replace(_ replacedNode: RedBlackTreeNode, with newNode: RedBlackTreeNode?) {
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

    private func fixTree(afterInserting newNode: RedBlackTreeNode) {
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

    private func fixTree(afterDeleting node: RedBlackTreeNode?, parentNode: RedBlackTreeNode) {
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

    private func rotateLeft(_ p: RedBlackTreeNode) {
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

    private func rotateRight(_ p: RedBlackTreeNode) {
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

    private func sibling(to node: RedBlackTreeNode) -> RedBlackTreeNode? {
        if node === node.parent?.left {
            return node.parent?.right
        } else {
            return node.parent?.left
        }
    }

    private func sibling(to node: RedBlackTreeNode?, through parentNode: RedBlackTreeNode) -> RedBlackTreeNode? {
        assert(node == nil || node?.parent === parentNode)
        if node === parentNode.left {
            return parentNode.right
        } else {
            return parentNode.left
        }
    }

    private func getColor(of node: RedBlackTreeNode?) -> RedBlackTreeNode.Color {
        return node?.color ?? .black
    }
}

extension RedBlackTree: CustomDebugStringConvertible {
    var debugDescription: String {
        return append(root, to: "", indent: 0)
    }

    private func append(_ node: RedBlackTreeNode, to string: String, indent: Int) -> String {
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
