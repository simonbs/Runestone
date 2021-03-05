//
//  TreeSitterIndentController.swift
//  
//
//  Created by Simon Støvring on 24/02/2021.
//

import Foundation

protocol TreeSitterIndentControllerDelegate: AnyObject {
    func treeSitterIndentController(_ controller: TreeSitterIndentController, stringIn range: NSRange) -> String
}

final class TreeSitterIndentController {
    weak var delegate: TreeSitterIndentControllerDelegate?
    let indentationScopes: TreeSitterIndentationScopes
    let languageMode: TreeSitterLanguageMode
    let tabLength = 2

    private var currentDelegate: TreeSitterIndentControllerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Delegate of \(type(of: self)) is unavailable")
        }
    }

    init(languageMode: TreeSitterLanguageMode, indentationScopes: TreeSitterIndentationScopes) {
        self.languageMode = languageMode
        self.indentationScopes = indentationScopes
    }

    func suggestedIndentLevel(for line: DocumentLineNode) -> Int {
        let range = NSRange(location: line.location, length: line.data.totalLength)
        guard let string = delegate?.treeSitterIndentController(self, stringIn: range) else {
            return 0
        }
//        var indentation = walkTree(startingAt: node)
//        if node.type == "comment" && node.startPoint.row < line.index && node.endPoint.row > line.index {
//            indentation += 1
//        }
        let linePosition = startingLinePosition(ofRow: line.index, in: string)
        if let node = languageMode.highestNode(at: linePosition) {
            return walkTree(startingAt: node)
        } else {
            return 0
        }
    }
}

private extension TreeSitterIndentController {
    private func startingLinePosition(ofRow row: Int, in string: String) -> LinePosition {
        // Find the first character that is not a whitespace
        var currentColumn = 0
        let whitespaceCharacters = Set([Symbol.Character.space, Symbol.Character.tab])
        if let stringIndex = string.firstIndex(where: { !whitespaceCharacters.contains($0) }) {
            let utf16View = string.utf16
            if let utf16Index = stringIndex.samePosition(in: string.utf16) {
                currentColumn = utf16View.distance(from: utf16View.startIndex, to: utf16Index)
            }
        }
        return LinePosition(row: row, column: currentColumn)
    }

    private func walkTree(startingAt node: TreeSitterNode) -> Int {
        guard let nodeType = node.type else {
            return 0
        }
        var increment = 0
        if indentationScopes.indent.contains(nodeType) {
            increment += 1
        }
        print(nodeType)
        print("  P: \(node.previousSibling?.type ?? "")")
        print("  N: \(node.nextSibling?.type ?? "")")
        if indentationScopes.outdent.contains(nodeType) {
            increment -= 1
        }

        if let parentNode = node.parent {
            return walkTree(startingAt: parentNode) + increment
        } else {
            return increment
        }

//        guard let nodeType = node.type, let parentNode = node.parent, let parentType = parentNode.type else {
//            return 0
//        }
//        var increment = 0
//        let notFirstOrLastSibling = node.previousSibling != nil && node.nextSibling != nil
//        let isScope = indentationScopes.indent.contains(parentType)
//        if notFirstOrLastSibling && isScope {
//            increment += 1
//        }
//        let isScope2 = indentationScopes.indentExceptFirst.contains(parentType)
//        if increment == 0 && isScope2 && node.previousSibling != nil {
//            increment += 1
//        }
//        let isScope3 = indentationScopes.indentExceptFirstOrBlock.contains(parentType)
//        if increment == 0 && isScope3 && node.previousSibling != nil {
//            increment += 1
//        }
//        var typeDent = 0
//        if indentationScopes.types.indent.contains(nodeType) {
//            typeDent += 1
//        }
//        if indentationScopes.types.outdent.contains(nodeType) && increment > 0 {
//            typeDent -= 1
//        }
//        increment += typeDent
//        if let previousScopeNode = previousScopeNode, increment > 0 &&
//            ((parentNode.startPoint.row == previousScopeNode.startPoint.row &&
//                parentNode.endByte <= previousScopeNode.endByte + ByteCount(1)) ||
//                (isScope3 && previousScopeNode.endByte == node.endByte)) {
//            increment = 0
//        }
//        if isScope || isScope2 {
//            return walkTree(startingAt: parentNode, previousScopeNode: parentNode) + increment
//        } else {
//            return walkTree(startingAt: parentNode, previousScopeNode: previousScopeNode) + increment
//        }
    }
}
