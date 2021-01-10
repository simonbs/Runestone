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

typealias DocumentLineNode = RedBlackTreeNode<DocumentLineNodeID, DocumentLineNodeData>
typealias LineFrameNode = RedBlackTreeNode<LineFrameNodeID, LineFrameNodeData>

struct VisibleLine {
    let documentLine: DocumentLineNode
    let lineFrame: LineFrameNode
}

final class LineManager {
    weak var delegate: LineManagerDelegate?
    var lineCount: Int {
        return documentLineTree.nodeTotalCount
    }
    var contentHeight: CGFloat {
        return 200
//        let rightMost = lineFrameTree.root.rightMost
//        return CGFloat(rightMost.location + rightMost.value)
    }
    var estimatedLineHeight: CGFloat = 12

    private let documentLineTree = RedBlackTree<DocumentLineNodeID, DocumentLineNodeData>(rootData: DocumentLineNodeData())
    private let lineFrameTree = RedBlackTree<LineFrameNodeID, LineFrameNodeData>(rootData: LineFrameNodeData())
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
        documentLineTree.reset(rootData: DocumentLineNodeData())
        documentLineNodeMap.removeAll()
        lineFrameNodeMap.removeAll()
        documentLineToLineFrameMap.removeAll()
        lineFrameToDocumentLineMap.removeAll()
        documentLineNodeMap[documentLineTree.root.id] = documentLineTree.root
        lineFrameNodeMap[lineFrameTree.root.id] = lineFrameTree.root
        documentLineToLineFrameMap[documentLineTree.root.id] = lineFrameTree.root.id
        lineFrameToDocumentLineMap[lineFrameTree.root.id] = documentLineTree.root.id
        documentLineTree.root.data.totalLength = documentLineTree.root.value
    }

    func removeCharacters(in range: NSRange) {
        guard range.length > 0 else {
            return
        }
        let startLine = documentLineTree.node(containgLocation: range.location)
        if range.location > Int(startLine.location) + startLine.data.length {
            // Deleting starting in the middle of a delimiter.
            setLength(of: startLine, to: startLine.value - 1)
            removeCharacters(in: NSRange(location: range.location, length: range.length - 1))
        } else if range.location + range.length < Int(startLine.location) + startLine.value {
            // Removing a part of the start line.
            setLength(of: startLine, to: startLine.value - range.length)
        } else {
            // Merge startLine with another line because the startLine's delimeter was deleted,
            // possibly removing lines in between if multiple delimeters were deleted.
            let charactersRemovedInStartLine = Int(startLine.location) + startLine.value - range.location
            assert(charactersRemovedInStartLine > 0)
            let endLine = documentLineTree.node(containgLocation: range.location + range.length)
            if endLine === startLine {
                // Removing characters in the last line.
                setLength(of: startLine, to: startLine.value - range.length)
            } else {
                let charactersLeftInEndLine = Int(endLine.location) + endLine.value - (range.location + range.length)
                // Remove all lines between startLine and endLine, excluding startLine but including endLine.
                var tmp = startLine.next
                var lineToRemove = tmp
                repeat {
                    lineToRemove = tmp
                    tmp = tmp.next
                    remove(lineToRemove)
                } while lineToRemove !== endLine
                let newLength = startLine.value - charactersRemovedInStartLine + charactersLeftInEndLine
                setLength(of: startLine, to: newLength)
            }
        }
    }

    func insert(_ string: NSString, at location: Int) {
        var line = documentLineTree.node(containgLocation: location)
        var lineLocation = Int(line.location)
        assert(location <= lineLocation + line.value)
        if location > lineLocation + line.data.length {
            // Inserting in the middle of a delimiter.
            setLength(of: line, to: line.value - 1)
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
                lineLocation = Int(line.location)
                let lengthAfterInsertionPos = lineLocation + line.value - (location + lastDelimiterEnd)
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
                setLength(of: line, to: line.value + string.length - lastDelimiterEnd)
            }
        } else {
            // No newline is being inserted. All the text is in a single line.
            setLength(of: line, to: line.value + string.length)
        }
    }

    func linePosition(at location: Int) -> LinePosition? {
        if let nodePosition = documentLineTree.nodePosition(at: location) {
            return LinePosition(
                lineStartLocation: nodePosition.nodeStartLocation,
                lineNumber: nodePosition.index,
                column: nodePosition.offset,
                totalLength: nodePosition.value)
        } else {
            return nil
        }
    }

    func line(containingCharacterAt location: Int) -> DocumentLineNode? {
        if location >= 0 && location <= Int(documentLineTree.nodeTotalValue) {
            return documentLineTree.node(containgLocation: location)
        } else {
            return nil
        }
    }

    func line(atIndex index: Int) -> DocumentLineNode {
        return documentLineTree.node(atIndex: index)
    }

//    @discardableResult
//    func setHeight(_ newHeight: CGFloat, of lineFrame: LineFrameNode) -> Bool {
//        if newHeight != CGFloat(lineFrame.value) {
//            lineFrame.value = newHeight
//            lineFrameTree.updateAfterChangingChildren(of: lineFrame)
//            return true
//        } else {
//            return false
//        }
//    }

//    func visibleLines(in rect: CGRect) -> [VisibleLine] {
//        let results = lineFrameTree.searchRange(Float(rect.minY) ... Float(rect.maxY))
//        return results.compactMap { result in
//            if let documentLineId = lineFrameToDocumentLineMap[result.node.id], let documentLine = documentLineNodeMap[documentLineId] {
//                return VisibleLine(documentLine: documentLine, lineFrame: result.node)
//            } else {
//                return nil
//            }
//        }
//    }
}

private extension LineManager {
    @discardableResult
    private func setLength(of line: DocumentLineNode, to newTotalLength: Int) -> DocumentLineNode {
        let delta = newTotalLength - line.value
        if delta != 0 {
            line.value = newTotalLength
            line.data.totalLength = newTotalLength
            documentLineTree.updateAfterChangingChildren(of: line)
        }
        // Determine new delimiter length.
        if newTotalLength == 0 {
            line.data.delimiterLength = 0
        } else {
            let lastChar = getCharacter(at: Int(line.location) + newTotalLength - 1)
            if lastChar == Symbol.carriageReturn {
                line.data.delimiterLength = 1
            } else if lastChar == Symbol.lineFeed {
                if newTotalLength >= 2 && getCharacter(at: Int(line.location) + newTotalLength - 2) == Symbol.carriageReturn {
                    line.data.delimiterLength = 2
                } else if newTotalLength == 1 && line.location > 0 && getCharacter(at: Int(line.location) - 1) == Symbol.carriageReturn {
                    // We need to join this line with the previous line.
                    let previousLine = line.previous
                    remove(line)
                    return setLength(of: previousLine, to: previousLine.value + 1)
                } else {
                    line.data.delimiterLength = 1
                }
            } else {
                line.data.delimiterLength = 0
            }
        }
        return line
    }

    @discardableResult
    private func insertLine(ofLength length: Int, after otherLine: DocumentLineNode) -> DocumentLineNode {
        let insertedLine = documentLineTree.insertNode(value: length, data: DocumentLineNodeData(), after: otherLine)
        insertedLine.data.totalLength = length
//        documentLineNodeMap[insertedLine.id] = insertedLine
//        if let afterLineFrameNodeId = documentLineToLineFrameMap[otherLine.id], let afterLineFrameNode = lineFrameNodeMap[afterLineFrameNodeId] {
//            let insertedFrame = lineFrameTree.insertNode(withValue: estimatedLineHeight, after: afterLineFrameNode)
//            lineFrameNodeMap[insertedFrame.id] = insertedFrame
//            documentLineToLineFrameMap[insertedLine.id] = insertedFrame.id
//            lineFrameToDocumentLineMap[insertedFrame.id] = insertedLine.id
//        }
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
