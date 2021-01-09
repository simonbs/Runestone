//
//  LineManager.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation
import CoreGraphics

protocol LineManagerDelegate: class {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String
    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode)
    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode)
}

extension LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode) {}
    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode) {}
}

struct DocumentLineNodeID: RedBlackTreeNodeID, Hashable {
    let id = UUID()
}

struct LineFrameNodeID: RedBlackTreeNodeID, Hashable {
    let id = UUID()
}

typealias DocumentLineNode = RedBlackTreeNode<DocumentLineNodeID, Int, DocumentLineNodeContext>
typealias LineFrameNode = RedBlackTreeNode<LineFrameNodeID, CGFloat, LineFrameNodeContext>

struct VisibleLine {
    let documentLine: DocumentLineNode
    let lineFrame: LineFrameNode
}

final class LineManager {
    weak var delegate: LineManagerDelegate?
    var lineCount: Int {
        return documentLineTree.totalNodeCount
    }
    var contentHeight: CGFloat {
        let rightMost = lineFrameTree.root.rightMost
        return rightMost.location + rightMost.value
    }
    var estimatedLineHeight: CGFloat = 12

    private let documentLineTree: RedBlackTree<DocumentLineNodeID, Int, DocumentLineNodeContext>  = RedBlackTree(minimumValue: 0, rootValue: 0, rootContext: .init())
    private let lineFrameTree: RedBlackTree<LineFrameNodeID, CGFloat, LineFrameNodeContext> = RedBlackTree(minimumValue: 0, rootValue: 0, rootContext: .init())
    private var documentLineNodeMap: [DocumentLineNodeID: DocumentLineNode] = [:]
    private var lineFrameNodeMap: [LineFrameNodeID: LineFrameNode] = [:]
    private var documentLineToLineFrameMap: [DocumentLineNodeID: LineFrameNodeID] = [:]
    private var lineFrameToDocumentLineMap: [LineFrameNodeID: DocumentLineNodeID] = [:]
    private var currentDelegate: LineManagerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Attempted to access delegate but it is not available.")
        }
    }

    init() {
        reset()
    }

    func reset() {
        documentLineTree.reset(rootValue: 0, rootContext: DocumentLineNodeContext())
        lineFrameTree.reset(rootValue: 0, rootContext: LineFrameNodeContext())
        documentLineTree.root.context.node = documentLineTree.root
        documentLineNodeMap.removeAll()
        lineFrameNodeMap.removeAll()
        documentLineToLineFrameMap.removeAll()
        lineFrameToDocumentLineMap.removeAll()
        documentLineNodeMap[documentLineTree.root.id] = documentLineTree.root
        lineFrameNodeMap[lineFrameTree.root.id] = lineFrameTree.root
        documentLineToLineFrameMap[documentLineTree.root.id] = lineFrameTree.root.id
        lineFrameToDocumentLineMap[lineFrameTree.root.id] = documentLineTree.root.id
    }

    func removeCharacters(in range: NSRange) {
        guard range.length > 0 else {
            return
        }
        let startLine = documentLineTree.node(containingValue: range.location)
        if range.location > startLine.location + startLine.context.length {
            // Deleting starting in the middle of a delimiter.
            setLength(of: startLine, to: startLine.context.totalLength - 1)
            removeCharacters(in: NSRange(location: range.location, length: range.length - 1))
        } else if range.location + range.length < startLine.location + startLine.context.totalLength {
            // Removing a part of the start line.
            setLength(of: startLine, to: startLine.context.totalLength - range.length)
        } else {
            // Merge startLine with another line because the startLine's delimeter was deleted,
            // possibly removing lines in between if multiple delimeters were deleted.
            let charactersRemovedInStartLine = startLine.location + startLine.context.totalLength - range.location
            assert(charactersRemovedInStartLine > 0)
            let endLine = documentLineTree.node(containingValue: range.location + range.length)
            if endLine === startLine {
                // Removing characters in the last line.
                setLength(of: startLine, to: startLine.context.totalLength - range.length)
            } else {
                let charactersLeftInEndLine = endLine.location + endLine.context.totalLength - (range.location + range.length)
                // Remove all lines between startLine and endLine, excluding startLine but including endLine.
                var tmp = startLine.next
                var lineToRemove = tmp
                repeat {
                    lineToRemove = tmp
                    tmp = tmp.next
                    remove(lineToRemove)
                } while lineToRemove !== endLine
                let newLength = startLine.context.totalLength - charactersRemovedInStartLine + charactersLeftInEndLine
                setLength(of: startLine, to: newLength)
            }
        }
    }

    func insert(_ string: NSString, at location: Int) {
        var line = documentLineTree.node(containingValue: location)
        var lineLocation = line.location
        assert(location <= lineLocation + line.context.totalLength)
        if location > lineLocation + line.context.length {
            // Inserting in the middle of a delimiter.
            setLength(of: line, to: line.context.totalLength - 1)
            // Add new line.
            line = insertLine(ofLength: 1, after: line)
            line = setLength(of: line, to: 1)
        }
        if let rangeOfFirstNewLine = NewLineFinder.rangeOfNextNewLine(in: string, startingAt: 0) {
            var lastDelimiterEnd = 0
            var rangeOfNewLine = rangeOfFirstNewLine
            var hasReachedEnd = false
            while !hasReachedEnd {
                let lineBreakLocation = location + rangeOfNewLine.location + rangeOfNewLine.length
                lineLocation = line.location
                let lengthAfterInsertionPos = lineLocation + line.context.totalLength - (location + lastDelimiterEnd)
                line = setLength(of: line, to: lineBreakLocation - lineLocation)
                var newLine = insertLine(ofLength: lengthAfterInsertionPos, after: line)
                newLine = setLength(of: newLine, to: lengthAfterInsertionPos)
                line = newLine
                lastDelimiterEnd = rangeOfNewLine.location + rangeOfNewLine.length
                if let rangeOfNextNewLine = NewLineFinder.rangeOfNextNewLine(in: string, startingAt: lastDelimiterEnd) {
                    rangeOfNewLine = rangeOfNextNewLine
                } else {
                    hasReachedEnd = true
                }
            }
            // Insert rest of last delimiter.
            if lastDelimiterEnd != string.length {
                setLength(of: line, to: line.context.totalLength + string.length - lastDelimiterEnd)
            }
        } else {
            // No newline is being inserted. All the text is in a single line.
            setLength(of: line, to: line.context.totalLength + string.length)
        }
    }

    func linePosition(at location: Int) -> LinePosition? {
        if let nodePosition = documentLineTree.nodePosition(at: location) {
            return LinePosition(
                lineStartLocation: nodePosition.location,
                lineNumber: nodePosition.index,
                column: nodePosition.valueOffset,
                length: nodePosition.value,
                delimiterLength: nodePosition.context.delimiterLength)
        } else {
            return nil
        }
    }

    func line(containingCharacterAt location: Int) -> DocumentLineNode? {
        if location >= 0 && location <= documentLineTree.totalValue {
            return documentLineTree.node(containingValue: location)
        } else {
            return nil
        }
    }

    func line(atIndex index: Int) -> DocumentLineNode {
        return documentLineTree.node(atIndex: index)
    }

    @discardableResult
    func setHeight(_ newHeight: CGFloat, of lineFrame: LineFrameNode) -> Bool {
        if newHeight != lineFrame.value {
            lineFrame.value = newHeight
            lineFrameTree.updateAfterChangingChildren(of: lineFrame)
            return true
        } else {
            return false
        }
    }

    func visibleLines(in rect: CGRect) -> [VisibleLine] {
        let results = lineFrameTree.searchRange(rect.minY ... rect.maxY)
        return results.compactMap { result in
            if let documentLineId = lineFrameToDocumentLineMap[result.node.id], let documentLine = documentLineNodeMap[documentLineId] {
                return VisibleLine(documentLine: documentLine, lineFrame: result.node)
            } else {
                return nil
            }
        }
    }
}

private extension LineManager {
    @discardableResult
    private func setLength(of line: DocumentLineNode, to newTotalLength: Int) -> DocumentLineNode {
        let delta = newTotalLength - line.context.totalLength
        if delta != 0 {
            line.value = newTotalLength
            documentLineTree.updateAfterChangingChildren(of: line)
        }
        // Determine new delimiter length.
        if newTotalLength == 0 {
            line.context.delimiterLength = 0
        } else {
            let lastChar = getCharacter(at: line.location + newTotalLength - 1)
            if lastChar == Symbol.carriageReturn {
                line.context.delimiterLength = 1
            } else if lastChar == Symbol.lineFeed {
                if newTotalLength >= 2 && getCharacter(at: line.location + newTotalLength - 2) == Symbol.carriageReturn {
                    line.context.delimiterLength = 2
                } else if newTotalLength == 1 && line.location > 0 && getCharacter(at: line.location - 1) == Symbol.carriageReturn {
                    // We need to join this line with the previous line.
                    let previousLine = line.previous
                    remove(line)
                    return setLength(of: previousLine, to: previousLine.context.totalLength + 1)
                } else {
                    line.context.delimiterLength = 1
                }
            } else {
                line.context.delimiterLength = 0
            }
        }
        return line
    }

    @discardableResult
    private func insertLine(ofLength length: Int, after otherLine: DocumentLineNode) -> DocumentLineNode {
        let insertedLine = documentLineTree.insertNode(withValue: length, context: DocumentLineNodeContext(), after: otherLine)
        insertedLine.context.node = insertedLine
        documentLineNodeMap[insertedLine.id] = insertedLine
        if let afterLineFrameNodeId = documentLineToLineFrameMap[otherLine.id], let afterLineFrameNode = lineFrameNodeMap[afterLineFrameNodeId] {
            let insertedFrame = lineFrameTree.insertNode(withValue: estimatedLineHeight, context: LineFrameNodeContext(), after: afterLineFrameNode)
            lineFrameNodeMap[insertedFrame.id] = insertedFrame
            documentLineToLineFrameMap[insertedLine.id] = insertedFrame.id
            lineFrameToDocumentLineMap[insertedFrame.id] = insertedLine.id
        }
        delegate?.lineManager(self, didInsert: insertedLine)
        return insertedLine
    }

    private func remove(_ line: DocumentLineNode) {
        documentLineTree.remove(line)
        documentLineNodeMap.removeValue(forKey: line.id)
        if let lineFrameNodeId = documentLineToLineFrameMap[line.id] {
            lineFrameNodeMap.removeValue(forKey: lineFrameNodeId)
            lineFrameToDocumentLineMap.removeValue(forKey: lineFrameNodeId)
        }
        documentLineToLineFrameMap.removeValue(forKey: line.id)
        delegate?.lineManager(self, didRemove: line)
    }

    private func getCharacter(at location: Int) -> String {
        return currentDelegate.lineManager(self, characterAtLocation: location)
    }
}
