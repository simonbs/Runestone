//
//  DocumentLine.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

final class DocumentLine: LineNode {
    var nodeTotalLength: Int = 0
    var nodeTotalCount: Int = 1
    private(set) var location = 0
    var totalLength = 0
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
