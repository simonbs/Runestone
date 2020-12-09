//
//  LineManager.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

@objc public protocol LineManagerDelegate: class {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> NSString
}

@objc public final class LineManager: NSObject {
    @objc public weak var delegate: LineManagerDelegate?

    private let tree = DocumentLineTree()
    private var currentDelegate: LineManagerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Attempted to access delegate but it is not available.")
        }
    }

    @objc(removeCharactersInRange:) public func removeCharacters(in range: NSRange) {
        guard range.length > 0 else {
            return
        }
        let startLine = tree.line(at: range.location)
        if range.location > startLine.location + startLine.length {
            // Deleting starting in the middle of a delimiter.
            setLength(of: startLine, to: startLine.totalLength - 1)
            removeCharacters(in: NSRange(location: range.location, length: range.length - 1))
        } else if range.location + range.length < startLine.location + startLine.totalLength {
            // Removing a part of the start line.
            setLength(of: startLine, to: startLine.totalLength - range.length)
        } else {
            // Merge startLine with another line because the startLine's delimeter was deleted,
            // possibly removing lines in between if multiple delimeters were deleted.
            let charactersRemovedInStartLine = startLine.location + startLine.totalLength - range.location
            assert(charactersRemovedInStartLine > 0)
            let endLine = tree.line(at: range.location + range.length)
            if endLine === startLine {
                // Removing characters in the last line.
                setLength(of: startLine, to: startLine.totalLength - range.length)
            } else {
                let charactersLeftInEndLine = endLine.location + endLine.totalLength - (range.location + range.length)
                // Remove all lines between startLine and endLine, excluding startLine but including endLine.
                var tmp = startLine.next
                var lineToRemove = tmp
                repeat {
                    lineToRemove = tmp
                    tmp = tmp.next
                    remove(lineToRemove)
                } while lineToRemove !== endLine
                setLength(of: startLine, to: startLine.totalLength - charactersRemovedInStartLine + charactersLeftInEndLine)
            }
        }
    }

    @objc(insertString:inRange:) public func insert(_ string: NSString, in range: NSRange) {
        var line = tree.line(at: range.location)
        var lineLocation = line.location
        assert(range.location <= lineLocation + line.totalLength)
        if range.location > lineLocation + line.length {
            // Inserting in the middle of a delimiter.
            setLength(of: line, to: line.totalLength - 1)
            // Add new line.
            line = insertLine(ofLength: 1, after: line)
            line = setLength(of: line, to: 1)
        }
        if let rangeOfFirstNewLine = NewLineFinder.rangeOfNextNewLine(in: string, startingAt: 0) {
            var lastDelimiterEnd = 0
            var rangeOfNewLine = rangeOfFirstNewLine
            var keepInserting = true
            while keepInserting {
                let lineBreakLocation = range.location + rangeOfNewLine.location + rangeOfNewLine.length
                lineLocation = line.location
                let lengthAfterInsertionPos = lineLocation + line.totalLength  - (range.location + lastDelimiterEnd)
                line = setLength(of: line, to: lineBreakLocation - lineLocation)
                var newLine = insertLine(ofLength: lengthAfterInsertionPos, after: line)
                newLine = setLength(of: newLine, to: lengthAfterInsertionPos)
                line = newLine
                lastDelimiterEnd = rangeOfNewLine.location + rangeOfNewLine.length
                if let rangeOfNextNewLine = NewLineFinder.rangeOfNextNewLine(in: string, startingAt: lastDelimiterEnd) {
                    rangeOfNewLine = rangeOfNextNewLine
                    keepInserting = true
                } else {
                    keepInserting = false
                }
            }
            // Insert rest of last delimiter.
            if lastDelimiterEnd != string.length {
                setLength(of: line, to: line.totalLength + string.length - lastDelimiterEnd)
            }
        } else {
            // No newline is being inserted. All the text is in a single line.
            print("Typing on line \(line.lineNumber ?? -1)")
            setLength(of: line, to: line.totalLength + string.length)
        }
    }
}

private extension LineManager {
    @discardableResult
    private func setLength(of line: DocumentLine, to newTotalLength: Int) -> DocumentLine {
        let delta = newTotalLength - line.totalLength
        if delta != 0 {
            line.totalLength = newTotalLength
            tree.updateAfterChangingChildren(of: line)
        }
        // Determine new delimiter length.
        if newTotalLength == 0 {
            line.delimiterLength = 0
        } else {
            let lastChar = getCharacter(at: line.location + newTotalLength - 1)
            if lastChar == NewLineSymbol.nsCarriageReturn {
                line.delimiterLength = 1
            } else if lastChar == NewLineSymbol.nsLineFeed {
                if newTotalLength >= 2 && getCharacter(at: line.location + newTotalLength - 2) == NewLineSymbol.nsCarriageReturn {
                    line.delimiterLength = 2
                } else if newTotalLength == 1 && line.location > 0 && getCharacter(at: line.location - 1) == NewLineSymbol.nsCarriageReturn {
                    // We need to join this line with the previous line.
                    let previousLine = line.previous
                    remove(line)
                    return setLength(of: previousLine, to: previousLine.totalLength + 1)
                } else {
                    line.delimiterLength = 1
                }
            } else {
                line.delimiterLength = 0
            }
        }
        return line
    }

    @discardableResult
    private func insertLine(ofLength length: Int, after otherLine: DocumentLine) -> DocumentLine {
        return tree.insertLine(ofLength: length, after: otherLine)
    }

    private func remove(_ line: DocumentLine) {
        tree.remove(line)
    }

    private func getCharacter(at location: Int) -> NSString {
        return currentDelegate.lineManager(self, characterAtLocation: location)
    }
}
