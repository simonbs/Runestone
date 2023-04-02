import Combine

struct IndentationChecker {
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

    func isIndentation(at location: Int) -> Bool {
        guard let line = lineManager.value.line(containingCharacterAt: location) else {
            return false
        }
        let localLocation = location - line.location
        guard localLocation >= 0 else {
            return false
        }
        let indentLevelMeasurer = IndentLevelMeasurer(
            stringView: stringView.value,
            indentLengthInSpaces: indentStrategy.value.lengthInSpaces
        )
        let indentLevel = indentLevelMeasurer.indentLevel(ofLineStartingAt: line.location, ofLength: line.data.totalLength)
        let indentString = indentStrategy.value.string(indentLevel: indentLevel)
        return localLocation <= indentString.utf16.count
    }
}
