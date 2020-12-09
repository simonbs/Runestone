//
//  DocumentLineTree.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

final class DocumentLineTree {
    private enum Side {
        case left
        case right
    }

    private lazy var root = DocumentLine(tree: self, totalLength: 0)

    init() {
        root.color = .black
    }

    func line(at location: Int) -> DocumentLine {
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

    func location(of node: DocumentLine) -> Int {
        var location = node.left?.nodeTotalLength ?? 0
        var workingNode = node
        while let parentNode = workingNode.parent {
            if workingNode === workingNode.parent?.right {
                if let leftNode = node.parent?.left {
                    location += leftNode.nodeTotalLength
                }
                location += parentNode.totalLength
            }
            workingNode = parentNode
        }
        return location
    }

    @discardableResult
    func insertLine(ofLength length: Int, after existingLine: DocumentLine) -> DocumentLine {
        let newLine = DocumentLine(tree: self, totalLength: length)
        insert(newLine, after: existingLine)
        return newLine
    }

    func remove(_ line: DocumentLine) {
        fatalError("Not implemented")
    }

    func updateAfterChangingChildren(of node: DocumentLine) {
        var totalCount = 1
        var totalLength = node.totalLength
        if let leftLine = node.left {
            totalCount += leftLine.nodeTotalCount
            totalLength += leftLine.nodeTotalLength
        }
        if let rightLine = node.right {
            totalCount += rightLine.nodeTotalCount
            totalLength += rightLine.nodeTotalLength
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

private extension DocumentLineTree {
    private func insert(_ newLine: DocumentLine, after parentLine: DocumentLine) {
        newLine.parent = parentLine
        newLine.color = .red
        if parentLine.right == nil {
            parentLine.right = newLine
        } else {
            parentLine.left = newLine
        }
        updateAfterChangingChildren(of: parentLine)
        fixTree(afterInserting: newLine)
    }

    private func replace(_ replacedNode: DocumentLine, with newNode: DocumentLine?) {
        if replacedNode.parent == nil {
            assert(replacedNode === root)
            root = newNode!
        } else if replacedNode.parent?.left === replacedNode {
            replacedNode.parent?.left = newNode
        } else {
            replacedNode.parent?.right = newNode
        }
        if newNode != nil {
            newNode?.parent = replacedNode.parent
        }
        replacedNode.parent = nil
    }

    private func fixTree(afterInserting newLine: DocumentLine) {
        var node = newLine
        assert(node.color == .red)
        assert(node.left == nil || node.left?.color == .black)
        assert(node.right == nil || node.right?.color == .black)
        if var parentNode = node.parent, parentNode.color == .black {
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
                    // Recolor notes.
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

    private func rotateLeft(_ p: DocumentLine) {
        // Let q be p's right child.
        guard let q = p.right else {
            fatalError("Can't rotate left when p's right-hand side child is nil.")
        }
        assert(q.parent === p)
        // Set q to be the new root.
        replace(p, with: q)
        // Set p's right child to be q's left child.
        p.right = q.left
        if p.right != nil {
            p.right?.parent = p
        }
        q.left = p
        p.parent = q
        updateAfterChangingChildren(of: p)
    }

    private func rotateRight(_ p: DocumentLine) {
        // Let q be p's left child.
        guard let q = p.left else {
            fatalError("Can't rotate right when p's left-hand side child is nil.")
        }
        assert(q.parent === p)
        // Set q to be the new root.
        replace(p, with: q)
        // Set p's left child to be q's right child.
        p.left = q.right
        if p.left != nil {
            p.left?.parent = p
        }
        // Set q's right child to be p.
        updateAfterChangingChildren(of: p)
    }

    private func sibling(to line: DocumentLine) -> DocumentLine? {
        if line === line.parent?.left {
            return line.parent?.right
        } else {
            return line.parent?.left
        }
    }
}
