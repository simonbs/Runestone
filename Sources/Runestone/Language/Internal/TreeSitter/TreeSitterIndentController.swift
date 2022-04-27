import Foundation

final class TreeSitterIndentController {
    private let indentationScopes: TreeSitterIndentationScopes
    private let stringView: StringView
    private let lineManager: LineManager
    private let tabLength: Int

    init(indentationScopes: TreeSitterIndentationScopes, stringView: StringView, lineManager: LineManager, tabLength: Int) {
        self.indentationScopes = indentationScopes
        self.stringView = stringView
        self.lineManager = lineManager
        self.tabLength = tabLength
    }

    func strategyForInsertingLineBreak(between startNode: TreeSitterNode?,
                                       and endNode: TreeSitterNode?,
                                       caretStartPosition: LinePosition,
                                       caretEndPosition: LinePosition) -> InsertLineBreakIndentStrategy {
        var indentAdjustment = 0
        var outdentAdjustment = 0
        var indentingNode: TreeSitterNode?
        var outdentingNode: TreeSitterNode?
        if let startNode = startNode, let nodeIncreasingIndentLevel = nodeIncreasingIndentLevel(from: startNode, caretPosition: caretStartPosition) {
            indentingNode = nodeIncreasingIndentLevel
            indentAdjustment = max(indentLevelAdjustment(from: nodeIncreasingIndentLevel), 0) + 1
        }
        if let endNode = endNode, let nodeDecrasingIndentLevel = nodeDecreasingIndentLevel(from: endNode, caretPosition: caretEndPosition) {
            outdentingNode = nodeDecrasingIndentLevel
            outdentAdjustment = min(indentLevelAdjustment(from: nodeDecrasingIndentLevel), 0) - 1
        }
        if indentAdjustment > 0 && outdentAdjustment < 0, let indentingNode = indentingNode {
            let currentIndentLevel = indentLevelOfLine(atRow: Int(indentingNode.startPoint.row))
            return InsertLineBreakIndentStrategy(indentLevel: currentIndentLevel + 1, insertExtraLineBreak: true)
        } else if indentAdjustment > 0, let indentingNode = indentingNode {
            // We preserve the indent level of the previous line so users have a chance to correct any indentation
            // we might have gotten wrong previously and work from that indent level.
            // We only increment the indent level by one, even if the line contains multiple nodes that would
            // increase the indent level. Most users probably don't want to indent a new line multiple times.
            let currentIndentLevel = indentLevelOfLine(atRow: Int(indentingNode.startPoint.row))
            return InsertLineBreakIndentStrategy(indentLevel: currentIndentLevel + 1, insertExtraLineBreak: false)
        } else if outdentAdjustment < 0, let outdentingNode = outdentingNode {
            // Find the starting node.
            var startingNode = outdentingNode
            while startingNode.startPoint.row == outdentingNode.startPoint.row, let parent = startingNode.parent {
                startingNode = parent
            }
            let row = Int(startingNode.startPoint.row)
            let startingIndentLevel = indentLevelOfLine(atRow: row)
            return InsertLineBreakIndentStrategy(indentLevel: startingIndentLevel, insertExtraLineBreak: false)
        } else {
            // We don't indent or outdent. We just keep the current indent level.
            let currentIndentLevel = indentLevelOfLine(atRow: caretStartPosition.row)
            return InsertLineBreakIndentStrategy(indentLevel: currentIndentLevel, insertExtraLineBreak: false)
        }
    }
}

private extension TreeSitterIndentController {
    private func indentLevelAdjustment(from node: TreeSitterNode) -> Int {
        // Loop through sibling nodes that start on the current line and check if any increases or decreases
        // the indent level. Consider the following line which would increase the indent level when inserting
        // a line break after the pipe (|), assuming the language is HTML.
        //   <div>|
        // However, inserting a line break after the pipe on the following line should not increase the indent level.
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
    private func nodeIncreasingIndentLevel(from node: TreeSitterNode, caretPosition: LinePosition) -> TreeSitterNode? {
        var workingNode: TreeSitterNode? = node
        if indentationScopes.whitespaceDenotesBlocks {
            workingNode = deepestChildNode(containing: caretPosition, startingAt: node)
        }
        while let node = workingNode, node.startPoint.row == caretPosition.row {
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
                //    Inserting a line break where one of the pipes (|) are placed shouldn't increase the indent level but
                //    instead keep the indent level starting at the "if" node. This is needed because "elseif" and "else"
                //    are children of the "if" node.
                let shouldNodeIndent = indentationScopes.indent.contains(type) || indentationScopes.inheritIndent.contains(type)
                let isNodeBeforeTargetPosition = LinePosition(node.startPoint).column < caretPosition.column
                if shouldNodeIndent && isNodeBeforeTargetPosition {
                    return node
                }
            }
            workingNode = node.parent
        }
        return nil
    }

    /// Looks for a node that decreases the indentation level and is on the line of the `targetLinePosition` but after its column.
    /// The node can be used to determine the indentation level of a new line and if we should insert an additional line break.
    private func nodeDecreasingIndentLevel(from node: TreeSitterNode, caretPosition: LinePosition) -> TreeSitterNode? {
        var workingNode: TreeSitterNode? = node
        while let node = workingNode, node.startPoint.row == caretPosition.row {
            if let type = node.type, indentationScopes.outdent.contains(type) {
                if node.startPoint.column >= caretPosition.column {
                    return node
                }
            }
            workingNode = node.parent
        }
        return nil
    }

    private func indentLevelOfLine(atRow row: Int) -> Int {
        // Get indentation level of line before the supplied line position.
        let line = lineManager.line(atRow: row)
        let measurer = IndentLevelMeasurer(stringView: stringView)
        return measurer.indentLevel(lineStartLocation: line.location, lineTotalLength: line.data.totalLength, tabLength: tabLength)
    }

    /// Finds the deepest child node that contains the specified location. This is used in languages where whitespace denotes a block.
    /// This includes Python and YAML. In those languages we cannot rely solely on the caret location when indenting.
    /// Consider the following Python:
    ///
    /// def helloWorld():|
    ///
    /// The caret is placed at the pipe (|). Pressing enter will insert a line break in the `module` scope.
    /// This is the outermost scope and it does not indent. Instead we find the deepest child that contains the caret.
    /// That happens to be a `block` which does in fact indent.
    private func deepestChildNode(containing linePosition: LinePosition, startingAt node: TreeSitterNode) -> TreeSitterNode? {
        let point = TreeSitterTextPoint(linePosition)
        guard node.startPoint.row < point.row || (node.startPoint.row == point.row && point.column >= node.startPoint.column) else {
            return nil
        }
        guard node.endPoint.row > point.row || (node.endPoint.row == point.row && point.column <= node.endPoint.column) else {
            return nil
        }
        // Assumes that children of are node are ordered so the deeper nodes are the last children.
        // This assumption have not been proven to hold but it appears that it does.
        for index in (0 ..< node.childCount).reversed() {
            if let child = node.child(at: index), let childResult = deepestChildNode(containing: linePosition, startingAt: child) {
                return childResult
            }
        }
        return node
    }
}
