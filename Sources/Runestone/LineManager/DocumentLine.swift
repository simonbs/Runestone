//
//  DocumentLine.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

final class DocumentLine: LineNode {
    enum Color {
        case black
        case red
    }

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
    var lineNumber: Int? {
        return tree.index(of: self)
    }
    var left: DocumentLine?
    var right: DocumentLine?
    var parent: DocumentLine?
    var color: Color = .black

    private weak var _tree: DocumentLineTree?
    private var tree: DocumentLineTree {
        if let tree = _tree {
            return tree
        } else {
            fatalError("Accessing tree after it has been deallocated.")
        }
    }

    init(tree: DocumentLineTree, totalLength: Int) {
        self._tree = tree
        self.nodeTotalCount = 1
        self.nodeTotalLength = totalLength
        self.totalLength = totalLength
    }
}

extension DocumentLine: CustomDebugStringConvertible {
    var debugDescription: String {
        let strLineNumber = lineNumber == nil ? "N/A" : "\(lineNumber!)"
        return "[DocumentLine lineNumber=\(strLineNumber) location=\(location) length=\(length)]"
    }
}
