import CoreText
import Foundation

struct CharacterLineBreakSuggester: LineBreakSuggesting {
    let maximumLineFragmentWidthProvider: MaximumLineFragmentWidthProviding

    func suggestLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        typesetUsing typesetter: CTTypesetter
    ) -> Int {
        let length = CTTypesetterSuggestClusterBreak(
            typesetter, 
            location,
            Double(maximumLineFragmentWidthProvider.maximumLineFragmentWidth)
        )
        guard location + length < attributedString.length else {
            // There is no character after suggested line break.
            return length
        }
        let lastCharacterIndex = location + length - 1
        let range = NSRange(location: lastCharacterIndex, length: 2)
        if attributedString.attributedSubstring(from: range).string == Symbol.carriageReturnLineFeed {
            // Suggested line break is in the middle of CRLF so return one position ahead which is after the character pair.
            return length + 1
        }
        return length
    }
}
