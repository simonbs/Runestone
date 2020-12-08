//
//  DocumentLineTree.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

final class DocumentLineTree {
    private lazy var root = DocumentLine(tree: self)

    init() {}

    func getByLocation(_ location: Int) -> DocumentLine {
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

    @discardableResult
    func insertLine(ofLength length: Int, after otherLine: DocumentLine) -> DocumentLine {
        fatalError("Not implemented")
    }

    func remove(_ line: DocumentLine) {
        fatalError("Not implemented")
    }

    func updateAfterChildrenChange(to line: DocumentLine) {
        var totalCount = 1
        var totalLength = line.totalLength
        if let leftLine = line.left {
            totalCount += leftLine.nodeTotalCount
            totalLength += leftLine.nodeTotalLength
        }
        if let rightLine = line.right {
            totalCount += rightLine.nodeTotalCount
            totalLength += rightLine.nodeTotalLength
        }
        if totalCount != line.nodeTotalCount || totalLength != line.nodeTotalLength {
            line.nodeTotalCount = totalCount
            line.nodeTotalLength = totalLength
            if let parent = line.parent {
                updateAfterChildrenChange(to: parent)
            }
        }
        print(root.nodeTotalLength)
    }
}
