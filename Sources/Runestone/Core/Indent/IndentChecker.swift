import Foundation

struct IndentChecker {
    let stringView: StringView
    let lineManager: LineManager
    let indentStrategy: IndentStrategy

    func isIndentation(at location: Int) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let localLocation = location - line.location
        guard localLocation >= 0 else {
            return false
        }
        let indentLevelMeasurer = IndentLevelMeasurer(stringView: stringView, indentLengthInSpaces: indentStrategy.lengthInSpaces)
        let indentLevel = indentLevelMeasurer.indentLevel(ofLineStartingAt: line.location, ofLength: line.data.totalLength)
        let indentString = indentStrategy.string(indentLevel: indentLevel)
        return localLocation <= indentString.utf16.count
    }
}
