import Combine

struct IndentationChecker<LineManagerType: LineManaging> {
    private let stringView: StringView
    private let lineManager: LineManagerType
    private let indentStrategy: CurrentValueSubject<IndentStrategy, Never>

    init(
        stringView: StringView,
        lineManager: LineManagerType,
        indentStrategy: CurrentValueSubject<IndentStrategy, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.indentStrategy = indentStrategy
    }

    func isIndentation(at location: Int) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let localLocation = location - line.location
        guard localLocation >= 0 else {
            return false
        }
        let indentLevelMeasurer = IndentLevelMeasurer(
            stringView: stringView,
            indentLengthInSpaces: indentStrategy.value.lengthInSpaces
        )
        let indentLevel = indentLevelMeasurer.indentLevel(
            ofLineStartingAt: line.location,
            ofLength: line.totalLength
        )
        let indentString = indentStrategy.value.string(indentLevel: indentLevel)
        return localLocation <= indentString.utf16.count
    }
}
