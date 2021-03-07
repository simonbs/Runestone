//
//  TreeSitterIndentController.swift
//  
//
//  Created by Simon Støvring on 24/02/2021.
//

import Foundation

final class TreeSitterIndentController {
    let indentationScopes: TreeSitterIndentationScopes
    let languageLayer: TreeSitterLanguageLayer

    private let stringView: StringView

    init(languageLayer: TreeSitterLanguageLayer, indentationScopes: TreeSitterIndentationScopes, stringView: StringView) {
        self.languageLayer = languageLayer
        self.indentationScopes = indentationScopes
        self.stringView = stringView
    }

    func indentLevel(in line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        var indentLength = 0
        let tabLength = indentBehavior.tabLength
        let location = line.location
        for i in 0 ..< line.data.totalLength {
            let range = NSRange(location: location + i, length: 1)
            let str = stringView.substring(in: range).first
            if str == Symbol.Character.tab {
                indentLength += tabLength - (indentLength % tabLength)
            } else if str == Symbol.Character.space {
                indentLength += 1
            } else {
                break
            }
        }
        return indentLength / tabLength
    }

    func suggestedIndentLevel(for line: DocumentLineNode) -> Int {
        let range = NSRange(location: line.location, length: line.data.totalLength)
        let string = stringView.substring(in: range)
        let linePosition = startingLinePosition(ofRow: line.index, in: string)
        return suggestedIndentLevel(at: linePosition.column, in: line)
    }

    func suggestedIndentLevel(at location: Int, in line: DocumentLineNode) -> Int {
        let linePosition = LinePosition(row: line.index, column: location)
        if let node = languageLayer.highestNode(at: linePosition) {
            return indentationLevel(at: node)
        } else {
            return 0
        }
    }

    func firstNodeAddingAdditionalLineBreak(from node: TreeSitterNode) -> TreeSitterNode? {
       var workingNode: TreeSitterNode? = node
       while let node = workingNode {
           if let type = node.type, indentationScopes.indentsAddingAdditionalLineBreak.contains(type) {
               return node
           }
           workingNode = node.parent
       }
       return nil
    }

    func firstNodeAddingIndentLevel(from node: TreeSitterNode) -> TreeSitterNode? {
       var workingNode: TreeSitterNode? = node
       while let node = workingNode {
           if let type = node.type, indentationScopes.indent.contains(type) {
               return node
           }
           workingNode = node.parent
       }
       return nil
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

    private func indentationLevel(at node: TreeSitterNode, previousScopeNode: TreeSitterNode? = nil) -> Int {
        guard let nodeType = node.type, let parentNode = node.parent, let parentType = parentNode.type else {
            return 0
        }
        var increment = 0
        let isScope = indentationScopes.indent.contains(parentType)
        if isScope {
            increment += 1
        }
        let isScope2 = indentationScopes.indentExceptFirst.contains(parentType)
        if increment == 0 && isScope2 && node.previousSibling != nil {
            increment += 1
        }
        let isScope3 = indentationScopes.indentExceptFirstOrBlock.contains(parentType)
        if increment == 0 && isScope3 && node.previousSibling != nil {
            increment += 1
        }
        var typeDent = 0
        if indentationScopes.types.indent.contains(nodeType) {
            typeDent += 1
        }
        if indentationScopes.types.outdent.contains(nodeType) && increment > 0 {
            typeDent -= 1
        }
        increment += typeDent
        if let previousScopeNode = previousScopeNode, increment > 0 &&
            ((parentNode.startPoint.row == previousScopeNode.startPoint.row &&
                parentNode.endByte <= previousScopeNode.endByte + ByteCount(1)) ||
                (isScope3 && previousScopeNode.endByte == node.endByte)) {
            increment = 0
        }
        if isScope || isScope2 {
            return indentationLevel(at: parentNode, previousScopeNode: parentNode) + increment
        } else {
            return indentationLevel(at: parentNode, previousScopeNode: previousScopeNode) + increment
        }
    }
}
