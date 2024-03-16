import Foundation
import UIKit

protocol IndentControllerDelegate: AnyObject {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange)
    func indentController(_ controller: IndentController, shouldSelect range: NSRange)
    func indentControllerDidUpdateTabWidth(_ controller: IndentController)
}

final class IndentController {
    weak var delegate: IndentControllerDelegate?
    var stringView: StringView
    var lineManager: LineManager
    var languageMode: InternalLanguageMode
    var indentFont: UIFont {
        didSet {
            if indentFont != oldValue {
                _tabWidth = nil
            }
        }
    }
    var indentStrategy: IndentStrategy {
        didSet {
            if indentStrategy != oldValue {
                _tabWidth = nil
            }
        }
    }
    var tabWidth: CGFloat {
        if let tabWidth = _tabWidth {
            return tabWidth
        } else {
            let tabWidth = TabWidthMeasurer.tabWidth(tabLength: indentStrategy.tabLength, font: indentFont)
            if tabWidth != _tabWidth {
                _tabWidth = tabWidth
                delegate?.indentControllerDidUpdateTabWidth(self)
            }
            return tabWidth
        }
    }

    private var _tabWidth: CGFloat?

    init(stringView: StringView, lineManager: LineManager, languageMode: InternalLanguageMode, indentStrategy: IndentStrategy, indentFont: UIFont) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.indentStrategy = indentStrategy
        self.indentFont = indentFont
    }

    func shiftLeft(in selectedRange: NSRange) {
        let lines = lineManager.lines(in: selectedRange)
        let originalRange = range(surrounding: lines)
        var newSelectedRange = selectedRange
        var replacementString: String?
        let indentString = indentStrategy.string(indentLevel: 1)
        let utf8IndentLength = indentString.count
        let utf16IndentLength = indentString.utf16.count
        for (lineIndex, line) in lines.enumerated() {
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            let lineString = stringView.substring(in: lineRange) ?? ""
            guard lineString.hasPrefix(indentString) else {
                replacementString = (replacementString ?? "") + lineString
                continue
            }
            let startIndex = lineString.index(lineString.startIndex, offsetBy: utf8IndentLength)
            let endIndex = lineString.endIndex
            replacementString = (replacementString ?? "") + lineString[startIndex ..< endIndex]
            if lineIndex == 0 {
                // We don't want the selection to move to the previous line when we can't shift left anymore.
                // Therefore we keep it to the minimum location, which is the location the line starts on.
                // If we try to exceed that, we need to adjust the length of the selected range.
                let preferredLocation = newSelectedRange.location - utf16IndentLength
                let newLocation = max(preferredLocation, originalRange.location)
                newSelectedRange.location = newLocation
                if newLocation > preferredLocation {
                    let preferredLength = newSelectedRange.length - (newLocation - preferredLocation)
                    newSelectedRange.length = max(preferredLength, 0)
                }
            } else {
                newSelectedRange.length -= utf16IndentLength
            }
        }
        if let replacementString = replacementString {
            delegate?.indentController(self, shouldInsert: replacementString, in: originalRange)
            delegate?.indentController(self, shouldSelect: newSelectedRange)
        }
    }

    func shiftRight(in selectedRange: NSRange) {
        let lines = lineManager.lines(in: selectedRange)
        let originalRange = range(surrounding: lines)
        var newSelectedRange = selectedRange
        var replacementString: String?
        let indentString = indentStrategy.string(indentLevel: 1)
        let indentLength = indentString.utf16.count
        for (lineIndex, line) in lines.enumerated() {
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            let lineString = stringView.substring(in: lineRange) ?? ""
            replacementString = (replacementString ?? "") + indentString + lineString
            if lineIndex == 0 {
                newSelectedRange.location += indentLength
            } else {
                newSelectedRange.length += indentLength
            }
        }
        if let replacementString = replacementString {
            delegate?.indentController(self, shouldInsert: replacementString, in: originalRange)
            delegate?.indentController(self, shouldSelect: newSelectedRange)
        }
    }

    func insertLineBreak(in range: NSRange, using lineEnding: LineEnding) {
        let symbol = lineEnding.symbol
        if let startLinePosition = lineManager.linePosition(at: range.lowerBound),
            let endLinePosition = lineManager.linePosition(at: range.upperBound) {
            let strategy = languageMode.strategyForInsertingLineBreak(from: startLinePosition, to: endLinePosition, using: indentStrategy)
            if strategy.insertExtraLineBreak {
                // Inserting a line break enters a new indentation level.
                // We insert an additional line break and place the cursor in the new block.
                let firstLineText = symbol + indentStrategy.string(indentLevel: strategy.indentLevel)
                let secondLineText = symbol + indentStrategy.string(indentLevel: strategy.indentLevel - 1)
                let indentedText = firstLineText + secondLineText
                delegate?.indentController(self, shouldInsert: indentedText, in: range)
                let newSelectedRange = NSRange(location: range.location + firstLineText.utf16.count, length: 0)
                delegate?.indentController(self, shouldSelect: newSelectedRange)
            } else {
                let indentedText = symbol + indentStrategy.string(indentLevel: strategy.indentLevel)
                delegate?.indentController(self, shouldInsert: indentedText, in: range)
            }
        } else {
            delegate?.indentController(self, shouldInsert: symbol, in: range)
        }
    }

    // Returns the range of an indentation text if the cursor is placed after an indentation.
    // This can be used when doing a deleteBackward operation to delete an indent level.
    func indentRangeInFrontOfLocation(_ location: Int) -> NSRange? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let tabLength: Int
        switch indentStrategy {
        case .tab:
            tabLength = 1
        case .space(let length):
            tabLength = length
        }
        let localLocation = location - line.location
        guard localLocation >= tabLength else {
            return nil
        }
        let indentLevel = languageMode.currentIndentLevel(of: line, using: indentStrategy)
        let indentString = indentStrategy.string(indentLevel: indentLevel)
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
    private func range(surrounding lines: [DocumentLineNode]) -> NSRange {
        let firstLine = lines[0]
        let lastLine = lines[lines.count - 1]
        let location = firstLine.location
        let length = (lastLine.location - location) + lastLine.data.totalLength
        return NSRange(location: location, length: length)
    }
}
