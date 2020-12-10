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
        return tree.index(of: self) + 1
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

    func asString() -> String {
        return "[DocumentLine lineNumber=\(lineNumber ?? -1) location=\(location) length=\(length)]"
    }
}

extension DocumentLine: CustomDebugStringConvertible {
    var debugDescription: String {
        return asString()
    }
}
