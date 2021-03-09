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

    func currentIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
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

    func suggestedIndentLevel(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        return indentLevel(at: linePosition, using: indentBehavior, alwaysUseSuggestion: true)
    }

    func indentLevelForInsertingLineBreak(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        return indentLevel(at: linePosition, using: indentBehavior, alwaysUseSuggestion: false)
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
    private func indentLevel(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior, alwaysUseSuggestion: Bool) -> Int {
        guard linePosition.row >= 0 else {
            return indentLevelOfLine(beforeLineAt: linePosition, indentBehavior: indentBehavior)
        }
        guard let node = languageLayer.node(at: linePosition) else {
            return indentLevelOfLine(beforeLineAt: linePosition, indentBehavior: indentBehavior)
        }
        guard let indentingNode = firstNodeAddingIndentLevel(from: node) else {
            return indentLevelOfLine(beforeLineAt: linePosition, indentBehavior: indentBehavior)
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
        } else if alwaysUseSuggestion {
            return indentLevel(at: node)
        } else {
            return indentLevelOfLine(beforeLineAt: linePosition, indentBehavior: indentBehavior)
        }
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

    private func indentLevelOfLine(beforeLineAt linePosition: LinePosition, indentBehavior: EditorIndentBehavior) -> Int {
        // Get indentation level of line before the supplied line position.
        let line = lineManager.line(atRow: linePosition.row)
        return currentIndentLevel(of: line, using: indentBehavior)
    }
}
