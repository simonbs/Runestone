import Foundation
import UIKit

protocol IndentControllerDelegate: AnyObject {
    @discardableResult
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) -> Bool
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
        let indentString = indentStrategy.string(indentLevel: 1)
        if let edit = IndentationEditPlanner.shiftLeft(lines: indentationLines(in: selectedRange),
                                                       selectedRange: selectedRange, indentString: indentString) {
            apply(edit)
        }
    }

    func shiftRight(in selectedRange: NSRange) {
        let indentString = indentStrategy.string(indentLevel: 1)
        if let edit = IndentationEditPlanner.shiftRight(lines: indentationLines(in: selectedRange),
                                                        selectedRange: selectedRange, indentString: indentString) {
            apply(edit)
        }
    }

    func insertLineBreak(in range: NSRange, using lineEnding: LineEnding) {
        let symbol = lineEnding.symbol
        if let startLinePosition = lineManager.linePosition(at: range.lowerBound),
            let endLinePosition = lineManager.linePosition(at: range.upperBound) {
            let strategy = languageMode.strategyForInsertingLineBreak(from: startLinePosition, to: endLinePosition, using: indentStrategy)
            let indentString = indentStrategy.string(indentLevel: strategy.indentLevel)
            if strategy.insertExtraLineBreak {
                let previousIndentString = indentStrategy.string(indentLevel: strategy.indentLevel - 1)
                apply(IndentationEditPlanner.insertLineBreak(in: range, symbol: symbol,
                                                             indentString: indentString,
                                                             previousIndentString: previousIndentString))
            } else {
                apply(IndentationEditPlanner.insertLineBreak(in: range, symbol: symbol, indentString: indentString))
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
        let indentLevel = languageMode.currentIndentLevel(of: line, using: indentStrategy)
        let indentString = indentStrategy.string(indentLevel: indentLevel)
        return IndentationEditPlanner.indentRange(inFrontOf: location, lineLocation: line.location,
                                                  currentIndentLength: indentString.utf16.count,
                                                  tabLength: tabLength)
    }
}

private extension IndentController {
    func indentationLines(in selectedRange: NSRange) -> [IndentationLine] {
        lineManager.lines(in: selectedRange).map { line in
            let range = NSRange(location: line.location, length: line.data.totalLength)
            return IndentationLine(range: range, text: stringView.substring(in: range) ?? "")
        }
    }

    func apply(_ edit: IndentationEdit) {
        guard delegate?.indentController(self, shouldInsert: edit.replacementText, in: edit.replacementRange) == true else {
            return
        }
        if let selectedRange = edit.selectedRange {
            delegate?.indentController(self, shouldSelect: selectedRange)
        }
    }
}
