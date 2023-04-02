import Combine
import Foundation

final class TextDeletionRangeFactory {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let indentRangeFactory: DeleteIndentRangeFactory
    private let characterPairRangeFactory: DeleteCharacterPairRangeFactory

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        indentRangeFactory: DeleteIndentRangeFactory,
        characterPairRangeFactory: DeleteCharacterPairRangeFactory
    ) {
        self.stringView = stringView
        self.indentRangeFactory = indentRangeFactory
        self.characterPairRangeFactory = characterPairRangeFactory
    }

    func rangeForDeletingText(in range: NSRange) -> NSRange {
        let composedCharactersRange = stringView.value.string.customRangeOfComposedCharacterSequences(for: range)
        if composedCharactersRange.length == 1, let indentRange = indentRangeFactory.rangeInFrontOfCharacter(at: range.lowerBound) {
            return indentRange
        } else if let characterPairRange = characterPairRangeFactory.rangeIncludingTrailingCharacterPairComponent(behind: range) {
            return characterPairRange
        } else {
            return composedCharactersRange
        }
    }
}
