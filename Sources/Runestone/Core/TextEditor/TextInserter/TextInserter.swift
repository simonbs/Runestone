import Combine
import Foundation

struct TextInserter {
    let lineManager: CurrentValueSubject<LineManager, Never>
    let selectedRange: CurrentValueSubject<NSRange, Never>
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    let lineEndings: CurrentValueSubject<LineEnding, Never>
    let indentStrategy: CurrentValueSubject<IndentStrategy, Never>
    let textReplacer: TextReplacer

    private var insertRange: NSRange {
        markedRange.value ?? selectedRange.value.nonNegativeLength
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
