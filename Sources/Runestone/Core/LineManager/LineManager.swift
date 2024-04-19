import _RunestoneRedBlackTree
import Foundation

typealias LineNode = RedBlackTreeNode<Int, ManagedLine>

final class LineManager<LineFactoryType: LineFactory>: LineManaging where LineFactoryType.LineType == ManagedLine {
    typealias State = EstimatedLineHeightReadable
    typealias LineType = LineFactoryType.LineType

    var lineCount: Int {
        tree.nodeTotalCount
    }

    private let state: State
    private let stringView: StringView
    private let lineFactory: LineFactoryType
    private var tree: RedBlackTree<Int, LineType>

    init(state: State, stringView: StringView, lineFactory: LineFactoryType) {
        self.state = state
        self.stringView = stringView
        self.lineFactory = lineFactory
        let rootLine = lineFactory.makeLine(estimatingHeightTo: state.estimatedLineHeight)
        self.tree = RedBlackTree(
            minimumValue: 0,
            rootValue: 0,
            rootData: rootLine,
            childrenUpdater: CompositeRedBlackTreeChildrenUpdater([
                AnyRedBlackTreeChildrenUpdater(TotalLineHeightRedBlackTreeChildrenUpdater()),
//                AnyRedBlackTreeChildrenUpdater(TotalByteCountRedBlackTreeChildrenUpdater())
            ])
        )
        rootLine.node = tree.root
    }

    func insertText(_ text: NSString, at location: Int) -> LineChangeSet<LineType> {
        var changeSet = LineChangeSet<LineType>()
        guard var line = lineNode(containingCharacterAt: location) else {
            return LineChangeSet()
        }
        var lineLocation = Int(line.location)
        assert(location <= lineLocation + line.value)
        if location > lineLocation + line.data.length {
            // Inserting in the middle of a delimiter.
            let otherChangeSetA = setLength(of: line, to: line.value - 1)
            changeSet = changeSet.union(otherChangeSetA)
            // Add new line.
            line = insertLine(ofLength: 1, after: line)
            changeSet.markLineInserted(line.data)
            let otherChangeSetB = setLength(of: line, to: 1, newLine: &line)
            changeSet = changeSet.union(otherChangeSetB)
        }
        guard let rangeOfFirstNewLine = NewLineFinder.rangeOfNextNewLine(in: text, startingAt: 0) else {
            // No newline is being inserted. All the text is in a single line.
            let otherChangeSet = setLength(of: line, to: line.value + text.length)
            changeSet = changeSet.union(otherChangeSet)
            return changeSet
        }
        var lastDelimiterEnd = 0
        var rangeOfNewLine = rangeOfFirstNewLine
        var hasReachedEnd = false
        while !hasReachedEnd {
            let lineBreakLocation = location + rangeOfNewLine.location + rangeOfNewLine.length
            lineLocation = Int(line.location)
            let lengthAfterInsertionPos = lineLocation + line.value - (location + lastDelimiterEnd)
            let otherChangeSetA = setLength(of: line, to: lineBreakLocation - lineLocation, newLine: &line)
            changeSet = changeSet.union(otherChangeSetA)
            var newLine = insertLine(ofLength: lengthAfterInsertionPos, after: line)
            changeSet.markLineInserted(newLine.data)
            let otherChangeSetB = setLength(of: newLine, to: lengthAfterInsertionPos, newLine: &newLine)
            changeSet = changeSet.union(otherChangeSetB)
            line = newLine
            lastDelimiterEnd = rangeOfNewLine.location + rangeOfNewLine.length
            if let rangeOfNextNewLine = NewLineFinder.rangeOfNextNewLine(in: text, startingAt: lastDelimiterEnd) {
                rangeOfNewLine = rangeOfNextNewLine
            } else {
                hasReachedEnd = true
            }
        }
        // Insert rest of last delimiter.
        if lastDelimiterEnd != text.length {
            let otherChangeSet = setLength(of: line, to: line.value + text.length - lastDelimiterEnd)
            changeSet = changeSet.union(otherChangeSet)
        }
        return changeSet
    }

    func removeText(in range: NSRange) -> LineChangeSet<LineType> {
        guard range.length > 0 else {
            return LineChangeSet()
        }
        guard let startLineNode = lineNode(containingCharacterAt: range.location) else {
            return LineChangeSet()
        }
        if range.location > Int(startLineNode.location) + startLineNode.data.length {
            // Deleting starting in the middle of a delimiter.
            var changeSet = LineChangeSet<LineType>()
            let otherChangeSetA = setLength(of: startLineNode, to: startLineNode.value - 1)
            changeSet = changeSet.union(otherChangeSetA)
            let removeRange = NSRange(location: range.location, length: range.length - 1)
            let otherChangeSetB = removeText(in: removeRange)
            changeSet = changeSet.union(otherChangeSetB)
            return changeSet
        } else if range.location + range.length < Int(startLineNode.location) + startLineNode.value {
            // Removing a part of the start line.
            return setLength(of: startLineNode, to: startLineNode.value - range.length)
        } else {
            // Merge startLine with another line because the startLine's delimeter was deleted,
            // possibly removing lines in between if multiple delimeters were deleted.
            let charactersRemovedInStartLine = Int(startLineNode.location) + startLineNode.value - range.location
            assert(charactersRemovedInStartLine > 0)
            guard let endLine = lineNode(containingCharacterAt: range.location + range.length) else {
                return LineChangeSet()
            }
            if endLine === startLineNode {
                // Removing characters in the last line.
                return setLength(of: startLineNode, to: startLineNode.value - range.length)
            } else {
                var changeSet = LineChangeSet<LineType>()
                let charactersLeftInEndLine = Int(endLine.location) + endLine.value - (range.location + range.length)
                // Remove all lines between startLine and endLine, excluding startLine but including endLine.
                var tmp = startLineNode.next
                var lineToRemove = tmp
                repeat {
                    lineToRemove = tmp
                    tmp = tmp.next
                    changeSet.markLineRemoved(lineToRemove.data)
                    tree.remove(lineToRemove)
                } while lineToRemove !== endLine
                let newLength = startLineNode.value - charactersRemovedInStartLine + charactersLeftInEndLine
                let otherChangeSet = setLength(of: startLineNode, to: newLength)
                changeSet = changeSet.union(otherChangeSet)
                return changeSet
            }
        }
    }

    func line(containingCharacterAt location: Int) -> LineType? {
        lineNode(containingCharacterAt: location)?.data
    }

    func line(atYOffset yOffset: CGFloat) -> LineType? {
        let query = YOffsetRedBlackTreeNodeByOffsetQuery(querying: tree, for: yOffset)
        let querier = RedBlackTreeNodeByOffsetQuerier(querying: tree)
        let node = querier.node(for: query)
        return node?.data
    }

    func makeLineIterator() -> AnyIterator<LineType> {
        AnyIterator(RedBlackTreeDataIterator(tree: tree))
    }

    subscript(row: Int) -> LineType {
        tree.node(atIndex: row).data
    }

    func rebuild() {
        // Reset the tree so we only have a single line.
        let rootLine = lineFactory.makeLine(estimatingHeightTo: state.estimatedLineHeight)
        tree.reset(rootValue: 0, rootData: rootLine)
        rootLine.node = tree.root
        let nsString = stringView.string as NSString
        // Iterate over lines in the string.
        var lineNode = tree.node(atIndex: 0)
        var workingNewLineRange = NewLineFinder.rangeOfNextNewLine(in: nsString, startingAt: 0)
        var lineNodes: [LineNode] = []
        var lastDelimiterEnd = 0
        var totalLineHeight: CGFloat = 0
        while let newLineRange = workingNewLineRange {
            let totalLength = newLineRange.location + newLineRange.length - lastDelimiterEnd
            lineNode.value = totalLength
            lineNode.data.totalLength = totalLength
            lineNode.data.delimiterLength = newLineRange.length
            lineNode.data.totalHeight = totalLineHeight
            lastDelimiterEnd = newLineRange.location + newLineRange.length
            lineNodes.append(lineNode)
            let line = lineFactory.makeLine(estimatingHeightTo: state.estimatedLineHeight)
            lineNode = RedBlackTree<Int, LineType>.Node(tree: tree, value: 0, data: line)
            line.node = lineNode
            workingNewLineRange = NewLineFinder.rangeOfNextNewLine(in: nsString, startingAt: lastDelimiterEnd)
            totalLineHeight += state.estimatedLineHeight
        }
        let totalLength = stringView.length - lastDelimiterEnd
        lineNode.value = totalLength
        lineNode.data.totalLength = totalLength
        lineNode.data.totalHeight = totalLineHeight
        lineNodes.append(lineNode)
        tree.rebuild(from: lineNodes)
    }
}

private extension LineManager {
    private func lineNode(containingCharacterAt location: Int) -> LineNode? {
        guard location >= 0 && location <= Int(tree.nodeTotalValue) else {
            return nil
        }
        let query = ValueRedBlackTreeNodeByOffsetQuery(querying: tree, for: location)
        let querier = RedBlackTreeNodeByOffsetQuerier(querying: tree)
        return querier.node(for: query)
    }

    private func setLength(of lineNode: LineNode, to newTotalLength: Int) -> LineChangeSet<LineType> {
        var newLine: LineNode = lineNode
        return setLength(of: lineNode, to: newTotalLength, newLine: &newLine)
    }

    private func setLength(
        of lineNode: LineNode,
        to newTotalLength: Int,
        newLine: inout LineNode
    ) -> LineChangeSet<LineType> {
        var changeSet = LineChangeSet<LineType>()
        changeSet.markLineEdited(lineNode.data)
//        let range = NSRange(location: line.location, length: newTotalLength)
//        let substring = stringView.substring(in: range)
//        let newByteCount = substring?.byteCount ?? 0
        if newTotalLength != lineNode.value 
            || newTotalLength != lineNode.data.totalLength
//            || newByteCount != line.data.byteCount
        {
            lineNode.value = newTotalLength
            lineNode.data.totalLength = newTotalLength
//            line.data.byteCount = newByteCount
            tree.updateAfterChangingChildren(of: lineNode)
        }
        // Determine new delimiter length.
        if newTotalLength == 0 {
            lineNode.data.delimiterLength = 0
        } else {
            let lastChar = getCharacter(at: Int(lineNode.location) + newTotalLength - 1)
            if lastChar == Symbol.carriageReturn {
                lineNode.data.delimiterLength = 1
            } else if lastChar == Symbol.lineFeed {
                if newTotalLength >= 2 && getCharacter(at: Int(lineNode.location) + newTotalLength - 2) == Symbol.carriageReturn {
                    lineNode.data.delimiterLength = 2
                } else if newTotalLength == 1 && lineNode.location > 0 && getCharacter(at: Int(lineNode.location) - 1) == Symbol.carriageReturn {
                    // We need to join this line with the previous line.
                    let previousLine = lineNode.previous
                    changeSet.markLineRemoved(lineNode.data)
                    tree.remove(lineNode)
                    let otherChangeSet = setLength(of: previousLine, to: previousLine.value + 1, newLine: &newLine)
                    changeSet = changeSet.union(otherChangeSet)
                } else {
                    lineNode.data.delimiterLength = 1
                }
            } else {
                lineNode.data.delimiterLength = 0
            }
        }
        newLine = lineNode
        return changeSet
    }

    @discardableResult
    private func insertLine(ofLength length: Int, after otherLine: LineNode) -> LineNode {
        let line = lineFactory.makeLine(estimatingHeightTo: state.estimatedLineHeight)
        let node = tree.insertNode(value: length, data: line, after: otherLine)
        line.node = node
//        let range = NSRange(location: insertedLine.location, length: length)
//        let substring = stringView.substring(in: range)
//        let byteCount = substring?.byteCount ?? 0
        node.data.totalLength = length
//        insertedLine.data.byteCount = byteCount
//        insertedLine.data.totalByteCount = byteCount
//        insertedLine.data.node = insertedLine
        // Call updateAfterChangingChildren(of:) to update the values of nodeTotalByteCount.
//        tree.updateAfterChangingChildren(of: insertedLine)
        return node
    }

    private func getCharacter(at location: Int) -> String? {
        let range = NSRange(location: location, length: 1)
        return stringView.substring(in: range)
    }
}

private extension LineNode {
    var location: Int {
        offset
    }
}
