//
//  IndentController.swift
//  
//
//  Created by Simon Støvring on 01/03/2021.
//

import Foundation
import UIKit

protocol IndentControllerDelegate: AnyObject {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange)
    func indentController(_ controller: IndentController, shouldSelect range: NSRange)
}

final class IndentController {
    weak var delegate: IndentControllerDelegate?
    var stringView: StringView
    var lineManager: LineManager
    var languageMode: LanguageMode
    var indentFont: UIFont {
        didSet {
            if indentFont != oldValue {
                _tabWidth = nil
            }
        }
    }
    var indentBehavior: EditorIndentBehavior {
        didSet {
            if indentBehavior != oldValue {
                _tabWidth = nil
            }
        }
    }
    var tabWidth: CGFloat {
        if let tabWidth = _tabWidth {
            return tabWidth
        } else {
            let str = String(repeating: " ", count: indentBehavior.tabLength)
            let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            let options: NSStringDrawingOptions = [.usesFontLeading, .usesLineFragmentOrigin]
            let attributes: [NSAttributedString.Key: Any] = [.font: indentFont]
            let bounds = str.boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
            let tabWidth = round(bounds.size.width)
            _tabWidth = tabWidth
            return tabWidth
        }
    }

    private var _tabWidth: CGFloat?

    init(stringView: StringView, lineManager: LineManager, languageMode: LanguageMode, indentBehavior: EditorIndentBehavior, indentFont: UIFont) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.indentBehavior = indentBehavior
        self.indentFont = indentFont
    }

    func shiftLeft(in range: NSRange) {
        let lines = lineManager.lines(in: range)
        let minimumLocation = lines[0].location
        var newSelectedRange = range
        for (lineIndex, line) in lines.enumerated() {
            let changeInLength = shiftLineRight(line)
            if lineIndex == 0 {
                // We don't want the selection to move to the previous line when we can't shift left anymore.
                // Therefore we keep it to the minimum location, which is the location the line starts on.
                // If we try to exceed that, we need to adjust the length of the selected range.
                let preferredLocation = newSelectedRange.location + changeInLength
                let newLocation = max(preferredLocation, minimumLocation)
                newSelectedRange.location = newLocation
                if newLocation > preferredLocation {
                    let preferredLength = newSelectedRange.length - (newLocation - preferredLocation)
                    newSelectedRange.length = max(preferredLength, 0)
                }
            } else {
                newSelectedRange.length += changeInLength
            }
        }
        delegate?.indentController(self, shouldSelect: newSelectedRange)
    }

    func shiftRight(in range: NSRange) {
        let lines = lineManager.lines(in: range)
        // If any line is below the suggested indent level then we move all lines to the suggested indent level.
        // If all lines are at the suggested indent level or greater then we increment the indent level of all lines.
        let anyLineBelowSuggestedIndentLevel = lines.contains { line in
            let currentIndentLevel = languageMode.currentIndentLevel(of: line, using: indentBehavior)
            let suggestedIndentLevel = languageMode.suggestedIndentLevel(of: line, using: indentBehavior)
            return currentIndentLevel < suggestedIndentLevel
        }
        var newSelectedRange = range
        for (lineIndex, line) in lines.enumerated() {
            let changeInLength: Int
            if anyLineBelowSuggestedIndentLevel {
                changeInLength = shiftLineToSuggestedIndentLevel(line)
            } else {
                changeInLength = shiftLineLeft(line)
            }
            if lineIndex == 0 {
                newSelectedRange.location += changeInLength
            } else {
                newSelectedRange.length += changeInLength
            }
        }
        delegate?.indentController(self, shouldSelect: newSelectedRange)
    }

    func insertLineBreak(in range: NSRange) {
        if let startLinePosition = lineManager.linePosition(at: range.lowerBound),
           let endLinePosition = lineManager.linePosition(at: range.upperBound),
           let line = lineManager.line(containingCharacterAt: range.lowerBound),
           languageMode.shouldInsertDoubleLineBreak(replacingRangeFrom: startLinePosition, to: endLinePosition) {
            // Cursor is placed between two brackets. Inserting a line break enters a new indentation level.
            // We insert an additional line break to move the closing bracket to a new line and place the cursor in the new block.
            let currentIndentLevel = languageMode.currentIndentLevel(of: line, using: indentBehavior)
            let firstLineText = Symbol.lineFeed + indentBehavior.string(indentLevel: currentIndentLevel + 1)
            let secondLineText = Symbol.lineFeed + indentBehavior.string(indentLevel: currentIndentLevel)
            let indentedText = firstLineText + secondLineText
            delegate?.indentController(self, shouldInsert: indentedText, in: range)
            let newSelectedRange = NSRange(location: range.location + firstLineText.utf16.count, length: 0)
            delegate?.indentController(self, shouldSelect: newSelectedRange)
        } else if let line = lineManager.line(containingCharacterAt: range.location) {
            // Indent the new line.
            let localLocation = range.location - line.location
            let linePosition = LinePosition(row: line.index, column: localLocation)
            let indentLevel = languageMode.indentLevelForInsertingLineBreak(at: linePosition, using: indentBehavior)
            let indentedText = Symbol.lineFeed + indentBehavior.string(indentLevel: indentLevel)
            delegate?.indentController(self, shouldInsert: indentedText, in: range)
        } else {
            delegate?.indentController(self, shouldInsert: Symbol.lineFeed, in: range)
        }
    }

    // Returns the range of an indentation text if the cursor is placed after an indentation.
    // This can be used when doing a deleteBackward operation to delete an indent level.
    func indentRangeInfrontOfLocation(_ location: Int) -> NSRange? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let tabLength = indentBehavior.tabLength
        let localLocation = location - line.location
        guard localLocation >= tabLength else {
            return nil
        }
        let indentLevel = languageMode.currentIndentLevel(of: line, using: indentBehavior)
        let indentString = indentBehavior.string(indentLevel: indentLevel)
        guard localLocation <= indentString.utf16.count else {
            return nil
        }
        guard localLocation % tabLength == 0 else {
            return nil
        }
        return NSRange(location: location - tabLength, length: tabLength)
    }
}

extension IndentController {
    @discardableResult
    private func shiftLineToSuggestedIndentLevel(_ line: DocumentLineNode) -> Int {
        let oldLength = line.data.totalLength
        let startLocation = line.location
        let endLocation = locationOfFirstNonWhitespaceCharacter(in: line)
        let range = NSRange(location: startLocation, length: endLocation - startLocation)
        let suggestedIndentLevel = languageMode.suggestedIndentLevel(of: line, using: indentBehavior)
        let indentString = indentBehavior.string(indentLevel: suggestedIndentLevel)
        delegate?.indentController(self, shouldInsert: indentString, in: range)
        return line.data.totalLength - oldLength
    }

    @discardableResult
    private func shiftLineLeft(_ line: DocumentLineNode) -> Int {
        let oldLength = line.data.totalLength
        let indentString = indentBehavior.string(indentLevel: 1)
        let startLocation = locationOfFirstNonWhitespaceCharacter(in: line)
        let range = NSRange(location: startLocation, length: 0)
        delegate?.indentController(self, shouldInsert: indentString, in: range)
        return line.data.totalLength - oldLength
    }

    @discardableResult
    private func shiftLineRight(_ line: DocumentLineNode) -> Int {
        let oldLength = line.data.totalLength
        let indentString = indentBehavior.string(indentLevel: 1)
        let indentUTF16Count = indentString.utf16.count
        guard line.data.length >= indentUTF16Count else {
            return 0
        }
        let indentRange = NSRange(location: line.location, length: indentUTF16Count)
        guard stringView.substring(in: indentRange) == indentString else {
            return 0
        }
        delegate?.indentController(self, shouldInsert: "", in: indentRange)
        return line.data.totalLength - oldLength
    }

    private func locationOfFirstNonWhitespaceCharacter(in line: DocumentLineNode) -> Int {
        var location = line.location
        let endLocation = location + line.data.length
        let whitespaceCharacters: Set<Character> = [Symbol.Character.space, Symbol.Character.tab]
        while location < endLocation {
            let character = stringView.character(at: location)
            if whitespaceCharacters.contains(character) {
                location += 1
            } else {
                break
            }
        }
        return location
    }
}
