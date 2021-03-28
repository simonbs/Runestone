//
//  TreeSitterIndentController.swift
//  
//
//  Created by Simon Støvring on 24/02/2021.
//

import Foundation

final class TreeSitterIndentController {
    private let indentationScopes: TreeSitterIndentationScopes?
    private let languageLayer: TreeSitterLanguageLayer
    private let stringView: StringView
    private let lineManager: LineManager

    init(languageLayer: TreeSitterLanguageLayer, indentationScopes: TreeSitterIndentationScopes?, stringView: StringView, lineManager: LineManager) {
        self.languageLayer = languageLayer
        self.indentationScopes = indentationScopes
        self.stringView = stringView
        self.lineManager = lineManager
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentStrategy: IndentStrategy) -> Int {
        var indentLength = 0
        let tabLength = indentStrategy.tabLength
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

    func strategyForInsertingLineBreak(at linePosition: LinePosition, using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy {
        var indentAdjustment = 0
        var outdentAdjustment = 0
        var outdentingNode: TreeSitterNode?
        let line = lineManager.line(atRow: linePosition.row)
        let indentIncreaseTargetLinePosition = indentIncreaseScanTargetLinePosition(from: linePosition, in: line)
        if let node = languageLayer.node(at: indentIncreaseTargetLinePosition) {
            if let indentingNode = nodeIncreasingIndentLevel(from: node, targetLinePosition: linePosition) {
                indentAdjustment = max(indentLevelAdjustment(from: indentingNode), 0) + 1
            }
        }
        if let node = languageLayer.node(at: linePosition) {
            if let _outdentingNode = nodeDecreasingIndentLevel(from: node, targetLinePosition: linePosition) {
                outdentingNode = _outdentingNode
                outdentAdjustment = min(indentLevelAdjustment(from: _outdentingNode), 0) - 1
            }
        }
        if indentAdjustment > 0 && outdentAdjustment < 0 {
            let currentIndentLevel = indentLevelOfLine(atRow: linePosition.row, indentStrategy: indentStrategy)
            return InsertLineBreakIndentStrategy(indentLevel: currentIndentLevel + 1, insertExtraLineBreak: true)
        } else if indentAdjustment > 0 {
            // We preserve the indent level of the previous line so users have a chance to correct any idnentation
            // we might have gotten wrong previously and work from that indent level.
            // We only increment the indent level by one, even if the line contains multiple nodes that would
            // increase the indent level. Most users probably don't want to indent a new line multiple times.
            let currentIndentLevel = indentLevelOfLine(atRow: linePosition.row, indentStrategy: indentStrategy)
            return InsertLineBreakIndentStrategy(indentLevel: currentIndentLevel + 1, insertExtraLineBreak: false)
        } else if outdentAdjustment < 0, let outdentingNode = outdentingNode {
            // Find the starting node
            var startingNode = outdentingNode
            while startingNode.startPoint.row == outdentingNode.startPoint.row, let parent = startingNode.parent {
                startingNode = parent
            }
            let row = Int(startingNode.startPoint.row)
            let startingIndentLevel = indentLevelOfLine(atRow: row, indentStrategy: indentStrategy)
            return InsertLineBreakIndentStrategy(indentLevel: startingIndentLevel, insertExtraLineBreak: false)
        } else {
            // We don't indent or outdent. We just keep the current indent level.
            let currentIndentLevel = indentLevelOfLine(atRow: linePosition.row, indentStrategy: indentStrategy)
            return InsertLineBreakIndentStrategy(indentLevel: currentIndentLevel, insertExtraLineBreak: false)
        }
    }
}

private extension TreeSitterIndentController {
    private func indentLevelAdjustment(from node: TreeSitterNode) -> Int {
        guard let indentationScopes = indentationScopes else {
            return 0
        }
        // Loop through sibling nodes that start on the current line and check if any increases or decreases
        // the indent level. Consider the following line which would increase the indent level when inserting
        // a line break after the pipe (|), assuming the language is HTML.
        //   <div>|
        // However, inserting a line break after the pipe on the followign line should not increase the indent level.
        //   <div></div>|
        var indentLevel = 0
        let startingRow = node.startPoint.row
        var workingNode = node
        while let currentNode = workingNode.nextSibling, currentNode.startPoint.row == startingRow {
            if let nodeType = currentNode.type {
                if indentationScopes.indent.contains(nodeType) {
                    indentLevel += 1
                }
                if indentationScopes.outdent.contains(nodeType) {
                    indentLevel -= 1
                }
            }
            workingNode = currentNode
        }
        return indentLevel
    }

    /// Looks for a node that increases the indentation level and is on the line of the `targetLinePosition` but before its column.
    /// The node can be used to determine the indentation level of a new line and if we should insert an addtional line break.
    private func nodeIncreasingIndentLevel(from node: TreeSitterNode, targetLinePosition: LinePosition) -> TreeSitterNode? {
        guard let indentationScopes = indentationScopes else {
            return nil
        }
        var workingNode: TreeSitterNode? = node
        while let node = workingNode, node.startPoint.row == targetLinePosition.row, node.startPoint.column <= targetLinePosition.column {
            if let type = node.type {
                // A node adds an indent level if it's type fulfills one of two:
                // 1. It indents. These nodes adds an indent level on their own.
                // 2. It inherits indenting. These node are branches that inherit the indenting level from a parent node.
                //    An example of this includes the "elsif" and "else" nodes in Ruby.
                //      if myBool
                //         # ...
                //      elseif myBool2|
                //         # ...
                //      else|
                //         # ...
                //      end
                //    Inserting a line break where on of the pipes (|) are placed shouldn't increase the indent level but
                //    instead keep the indent level starting at the "if" node. This is needed because "elseif" and "else"
                //    are children of the "if" node.
                let shouldNodeIndent = indentationScopes.indent.contains(type) || indentationScopes.inheritIndent.contains(type)
                let isNodeBeforeTargetPosition = node.startPoint.column < targetLinePosition.column
                if shouldNodeIndent && isNodeBeforeTargetPosition {
                    return node
                }
            }
            workingNode = node.parent
        }
        return nil
    }

    /// Looks for a node that decreases the indentation level and is on the line of the `targetLinePosition` but after its column.
    /// The node can be used to determine the indentation level of a new line and if we should insert an addtional line break.
    private func nodeDecreasingIndentLevel(from node: TreeSitterNode, targetLinePosition: LinePosition) -> TreeSitterNode? {
        guard let indentationScopes = indentationScopes else {
            return nil
        }
        var workingNode: TreeSitterNode? = node
        while let node = workingNode, node.startPoint.row == targetLinePosition.row, node.startPoint.column >= targetLinePosition.column {
            if let type = node.type {
                if indentationScopes.outdent.contains(type) {
                    return node
                }
            }
            workingNode = node.parent
        }
        return nil
    }
    
    private func indentLevelOfLine(atRow row: Int, indentStrategy: IndentStrategy) -> Int {
        // Get indentation level of line before the supplied line position.
        let line = lineManager.line(atRow: row)
        return currentIndentLevel(of: line, using: indentStrategy)
    }

    private func indentIncreaseScanTargetLinePosition(from linePosition: LinePosition, in line: DocumentLineNode) -> LinePosition {
        if let indentationScopes = indentationScopes, indentationScopes.indentScanLocation == .lineStart {
            let line = lineManager.line(atRow: linePosition.row)
            return startingLinePosition(of: line)
        } else {
            return linePosition
        }
    }

    private func startingLinePosition(of line: DocumentLineNode) -> LinePosition {
        // Find the first character that is not a whitespace
        let range = NSRange(location: line.location, length: line.data.totalLength)
        let string = stringView.substring(in: range)
        var currentColumn = 0
        let whitespaceCharacters = Set([Symbol.Character.space, Symbol.Character.tab])
        if let stringIndex = string.firstIndex(where: { !whitespaceCharacters.contains($0) }) {
            let utf16View = string.utf16
            if let utf16Index = stringIndex.samePosition(in: string.utf16) {
                currentColumn = utf16View.distance(from: utf16View.startIndex, to: utf16Index)
            }
        }
        return LinePosition(row: line.index, column: currentColumn)
    }
}
