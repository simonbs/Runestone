//
//  DocumentLine.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

final class DocumentLine {
    private(set) var location = 0
    var totalLength = 0
    var nodeTotalLength = 0
    var nodeTotalCount = 1
    var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    var length: Int {
        return totalLength - delimiterLength
    }
    private(set) var left: DocumentLine?
    private(set) var right: DocumentLine?
    private(set) var parent: DocumentLine?
    var leftMost: DocumentLine {
        var result = self
        while let newResult = result.left {
            result = newResult
        }
        return result
    }
    var rightMost: DocumentLine {
        var result = self
        while let newResult = result.right {
            result = newResult
        }
        return result
    }
    var previous: DocumentLine {
        if let left = left {
            return left.rightMost
        } else {
            var node: DocumentLine? = self
            var oldNode: DocumentLine? = self
            repeat {
                oldNode = node
                node = node?.parent
                // We are on the way up from the left part, don't output node again.
            } while node != nil && node?.left === oldNode
            return node!
        }
    }
    var next: DocumentLine {
        if let right = right {
            return right.leftMost
        } else {
            var node: DocumentLine? = self
            var oldNode: DocumentLine? = self
            repeat {
                oldNode = node
                node = node?.parent
                // We are on the way up from the right part, don't output node again.
            } while node != nil && node?.right === oldNode
            return node!
        }
    }

    private weak var _tree: DocumentLineTree?
    private var tree: DocumentLineTree {
        if let tree = _tree {
            return tree
        } else {
            fatalError("Accessing tree after it has been deallocated.")
        }
    }

    init(tree: DocumentLineTree) {
        self._tree = tree
    }
}
