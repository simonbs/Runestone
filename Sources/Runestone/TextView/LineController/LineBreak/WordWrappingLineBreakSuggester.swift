import CoreText
import Foundation

struct WordWrappingLineBreakSuggester {
    let typesetter: CTTypesetter
    let attributedString: NSAttributedString
    let constrainingWidth: CGFloat

    func suggestLineBreak(startingAt startOffset: Int) -> Int {
        let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, Double(constrainingWidth))
        guard startOffset + length < attributedString.length else {
            // We've reached the end of the line.
            return length
        }
        let lastCharacterIndex = startOffset + length - 1
        let prefersLineBreakAfterCharacter = prefersInsertingLineBreakAfterCharacter(at: lastCharacterIndex)
        guard !prefersLineBreakAfterCharacter else {
            // We're breaking at a whitespace so we return the break suggested by CTTypesetter.
            return length
        }
        // CTTypesetter did not suggest breaking at a whitespace. We try to go back in the string to find a whitespace to break at.
        // If that fails we'll just use the break suggested by CTTypesetter. This workaround solves two issues:
        // 1. The results more closely matches the behavior of desktop editors like Nova. They tend to prefer breaking at whitespaces.
        // 2. It fixes an issue where breaking in the middle of the /> ligature would cause the slash not to be drawn. More info in this tweet:
        //    https://twitter.com/simonbs/status/1515961709671899137
        let maximumLookback = min(length, 100)
        if let lookbackLength = lookbackToFindFirstLineBreakableCharacter(startingAt: startOffset + length, maximumLookback: maximumLookback) {
            return length - lookbackLength
        } else {
            return length
        }
    }
}

private extension WordWrappingLineBreakSuggester {
    private func lookbackToFindFirstLineBreakableCharacter(startingAt startLocation: Int, maximumLookback: Int) -> Int? {
        var lookback = 0
        var foundWhitespace = false
        while lookback < maximumLookback && !foundWhitespace {
            if prefersInsertingLineBreakAfterCharacter(at: startLocation - lookback) {
                foundWhitespace = true
            } else {
                lookback += 1
            }
        }
        if foundWhitespace {
            // Subtract one to break at the whitespace we've found.
            return lookback - 1
        } else {
            return nil
        }
    }

    private func prefersInsertingLineBreakAfterCharacter(at location: Int) -> Bool {
        let range = NSRange(location: location, length: 1)
        let attributedSubstring = attributedString.attributedSubstring(from: range)
        let string = attributedSubstring.string.trimmingCharacters(in: .whitespaces)
        return string.isEmpty || CharacterSet(charactersIn: string).isSubset(of: .punctuationCharacters)
    }
}
