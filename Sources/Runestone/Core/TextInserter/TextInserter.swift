import Combine
import Foundation

final class TextInserter {
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let markedRange: CurrentValueSubject<NSRange?, Never>
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let lineEndings: CurrentValueSubject<LineEnding, Never>
    private let indentStrategy: CurrentValueSubject<IndentStrategy, Never>
    private let textReplacer: TextReplacer
    private var insertRange: NSRange {
        markedRange.value ?? selectedRange.value.nonNegativeLength
    }

    init(
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        markedRange: CurrentValueSubject<NSRange?, Never>,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>,
        lineEndings: CurrentValueSubject<LineEnding, Never>,
        indentStrategy: CurrentValueSubject<IndentStrategy, Never>,
        textReplacer: TextReplacer
    ) {
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.markedRange = markedRange
        self.languageMode = languageMode
        self.lineEndings = lineEndings
        self.indentStrategy = indentStrategy
        self.textReplacer = textReplacer
    }

    func insertText(_ text: String) {
        if text == lineEndings.value.symbol {
            insertNewLine(in: insertRange)
        } else {
            textReplacer.replaceText(in: insertRange, with: text)
        }
    }

    func insertNewLine() {
        insertNewLine(in: insertRange)
    }

    func insertTab() {
        let text = indentStrategy.value.string(indentLevel: 1)
        textReplacer.replaceText(in: insertRange, with: text)
    }
}

private extension TextInserter {
    private func insertNewLine(in range: NSRange) {
        let symbol = lineEndings.value.symbol
        guard let startLinePosition = lineManager.value.linePosition(at: range.lowerBound) else {
            textReplacer.replaceText(in: range, with: symbol)
            return
        }
        guard let endLinePosition = lineManager.value.linePosition(at: range.upperBound) else {
            textReplacer.replaceText(in: range, with: symbol)
            return
        }
        let strategy = languageMode.value.strategyForInsertingLineBreak(from: startLinePosition, to: endLinePosition, using: indentStrategy.value)
        if strategy.insertExtraLineBreak {
            // Inserting a line break enters a new indentation level. We insert an additional line break and place the cursor in the new block.
            let firstLineText = symbol + indentStrategy.value.string(indentLevel: strategy.indentLevel)
            let secondLineText = symbol + indentStrategy.value.string(indentLevel: strategy.indentLevel - 1)
            let indentedText = firstLineText + secondLineText
            textReplacer.replaceText(in: range, with: indentedText)
            selectedRange.value = NSRange(location: range.location + firstLineText.utf16.count, length: 0)
        } else {
            let indentedText = symbol + indentStrategy.value.string(indentLevel: strategy.indentLevel)
            textReplacer.replaceText(in: range, with: indentedText)
        }
    }
}
