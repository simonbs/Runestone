import Foundation

struct IndentationTextEditor<
    LineManagerType: LineManaging, 
    InternalLanguageModeType: InternalLanguageMode
>: TextEditing {
    typealias State = IndentStrategyReadable
    & LineEndingsReadable
    & MarkedRangeReadable
    & SelectedRangeWritable

    let state: State
    let stringView: StringView
    let lineManager: LineManagerType
    let languageMode: InternalLanguageModeType
    let textEditor: TextEditing

    func insertText(_ text: String) {
        if text.isLineBreak {
            insertLineBreak()
        } else {
            textEditor.insertText(text)
        }
    }

    func replaceText(in range: NSRange, with newText: String) {
        textEditor.replaceText(in: range, with: newText)
    }

    func deleteBackward() {
        guard state.markedRange == nil && state.selectedRange.length == 0 else {
            return textEditor.deleteBackward()
        }
        guard let indentRange = indentRangeInFrontOfCharacter(at: state.selectedRange.location) else {
            return textEditor.deleteBackward()
        }
        textEditor.replaceText(in: indentRange, with: "")
    }

    func deleteForward() {
        textEditor.deleteForward()
    }

    func deleteWordForward() {
        textEditor.deleteWordForward()
    }

    func deleteWordBackward() {
        textEditor.deleteWordBackward()
    }
}

private extension IndentationTextEditor {
    private func insertLineBreak() {
        let range = state.selectedRange
        let symbol = state.lineEndings.symbol
        guard let startLinePosition = lineManager.linePosition(at: range.lowerBound) else {
            textEditor.replaceText(in: range, with: symbol)
            return
        }
        guard let endLinePosition = lineManager.linePosition(at: range.upperBound) else {
            textEditor.replaceText(in: range, with: symbol)
            return
        }
        let strategy = languageMode.strategyForInsertingLineBreak(
            from: startLinePosition,
            to: endLinePosition,
            using: state.indentStrategy
        )
        if strategy.insertExtraLineBreak {
            // Inserting a line break enters a new indentation level so we insert
            // an additional line break and place the cursor in the new block.
            let firstLineText = symbol + state.indentStrategy.string(indentLevel: strategy.indentLevel)
            let secondLineText = symbol + state.indentStrategy.string(indentLevel: strategy.indentLevel - 1)
            let indentedText = firstLineText + secondLineText
            textEditor.replaceText(in: range, with: indentedText)
            state.selectedRange = NSRange(location: range.location + firstLineText.utf16.count, length: 0)
        } else {
            let indentedText = symbol + state.indentStrategy.string(indentLevel: strategy.indentLevel)
            textEditor.replaceText(in: range, with: indentedText)
        }
    }

    private func indentRangeInFrontOfCharacter(at location: Int) -> NSRange? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let localLocation = location - line.location
        guard localLocation >= state.indentStrategy.indentLength else {
            return nil
        }
        let indentLevelMeasurer = IndentLevelMeasurer(
            stringView: stringView,
            indentLengthInSpaces: state.indentStrategy.lengthInSpaces
        )
        let indentLevel = indentLevelMeasurer.indentLevel(
            ofLineStartingAt: line.location,
            ofLength: line.totalLength
        )
        let indentString = state.indentStrategy.string(indentLevel: indentLevel)
        guard localLocation <= indentString.utf16.count else {
            return nil
        }
        guard localLocation % state.indentStrategy.indentLength == 0 else {
            return nil
        }
        return NSRange(
            location: location - state.indentStrategy.indentLength,
            length: state.indentStrategy.indentLength
        )
    }
}

private extension IndentStrategy {
    var indentLength: Int {
        switch self {
        case .tab:
            return 1
        case .space(let tabLength):
            return tabLength
        }
    }
}
