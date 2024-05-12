import Combine
import Foundation

final class IndentLevelMeasurer<StringViewType: StringView> {
    private let stringView: StringViewType
    private let indentLengthInSpaces: Int

    init(stringView: StringViewType, indentLengthInSpaces: Int) {
        self.stringView = stringView
        self.indentLengthInSpaces = indentLengthInSpaces
    }

    func indentLevel(ofLineStartingAt lineLocation: Int, ofLength lineLength: Int) -> Int {
        var indentLength = 0
        for i in 0 ..< lineLength {
            let range = NSRange(location: lineLocation + i, length: 1)
            if let str = stringView.substring(in: range)?.first {
                if str == Symbol.Character.tab {
                    indentLength += indentLengthInSpaces - (indentLength % indentLengthInSpaces)
                } else if str == Symbol.Character.space {
                    indentLength += 1
                } else {
                    break
                }
            }
        }
        return indentLength / indentLengthInSpaces
    }
}
