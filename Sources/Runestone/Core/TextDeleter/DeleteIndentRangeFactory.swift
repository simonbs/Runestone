import Combine
import Foundation

final class DeleteIndentRangeFactory {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let indentStrategy: CurrentValueSubject<IndentStrategy, Never>

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        indentStrategy: CurrentValueSubject<IndentStrategy, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.indentStrategy = indentStrategy
    }

    func rangeInFrontOfCharacter(at location: Int) -> NSRange? {
        guard let line = lineManager.value.line(containingCharacterAt: location) else {
            return nil
        }
        let localLocation = location - line.location
        guard localLocation >= indentStrategy.value.indentLength else {
            return nil
        }
        let indentLevelMeasurer = IndentLevelMeasurer(stringView: stringView.value, indentLengthInSpaces: indentStrategy.value.lengthInSpaces)
        let indentLevel = indentLevelMeasurer.indentLevel(ofLineStartingAt: line.location, ofLength: line.data.totalLength)
        let indentString = indentStrategy.value.string(indentLevel: indentLevel)
        guard localLocation <= indentString.utf16.count else {
            return nil
        }
        guard localLocation % indentStrategy.value.indentLength == 0 else {
            return nil
        }
        return NSRange(location: location - indentStrategy.value.indentLength, length: indentStrategy.value.indentLength)
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
