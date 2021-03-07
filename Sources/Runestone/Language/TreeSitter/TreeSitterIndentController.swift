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
    private let lineManager: LineManager

    init(languageLayer: TreeSitterLanguageLayer, indentationScopes: TreeSitterIndentationScopes, stringView: StringView, lineManager: LineManager) {
        self.languageLayer = languageLayer
        self.indentationScopes = indentationScopes
        self.stringView = stringView
        self.lineManager = lineManager
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

    func suggestedIndentLevel(for line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        let range = NSRange(location: line.location, length: line.data.totalLength)
        let string = stringView.substring(in: range)
        let linePosition = startingLinePosition(ofRow: line.index, in: string)
        return suggestedIndentLevel(at: linePosition, using: indentBehavior)
    }

    func suggestedIndentLevel(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        guard linePosition.row > 0 else {
            return 0
        }
        guard let node = languageLayer.highestNode(at: linePosition) else {
            return 0
        }
        guard let indentingNode = firstNodeAddingIndentLevel(from: node) else {
            return 0
        }
        if indentingNode.startPoint.row == linePosition.row {
            return indentLevel(at: node)
        } else if indentingNode.endPoint.row == linePosition.row {
            // If the indentation level ends at the inputted line then we'll subtract one from the indentation level.
            // This is the case when placing the cursor as shown below and adding a new line.
            //   if (foo) {
            //     // ...
            //   |}
            return max(indentLevel(at: node) - 1, 0)
        } else {
            // Keep the same indentation as the previous line.
            let line = lineManager.line(atRow: linePosition.row)
            return indentLevel(in: line, using: indentBehavior)
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

    private func indentLevel(at node: TreeSitterNode) -> Int {
        guard let nodeType = node.type else {
            return 0
        }
        var increment = 0
        if indentationScopes.indent.contains(nodeType) {
            increment += 1
        }
        if increment > 0 && indentationScopes.outdent.contains(nodeType) {
            increment -= 1
        }
        if let parentNode = node.parent {
            return indentLevel(at: parentNode) + increment
        } else {
            return increment
        }
    }

    private func firstNodeAddingIndentLevel(from node: TreeSitterNode) -> TreeSitterNode? {
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
