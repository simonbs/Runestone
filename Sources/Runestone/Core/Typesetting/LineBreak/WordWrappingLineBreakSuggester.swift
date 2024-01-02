import CoreText
import Foundation

struct WordWrappingLineBreakSuggester: LineBreakSuggesting {
    let maximumLineFragmentWidthProvider: MaximumLineFragmentWidthProviding

    func suggestLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        typesetUsing typesetter: CTTypesetter
    ) -> Int {
        let length = CTTypesetterSuggestLineBreak(
            typesetter,
            location,
            Double(maximumLineFragmentWidthProvider.maximumLineFragmentWidth)
        )
        guard location + length < attributedString.length else {
            // We've reached the end of the line.
            return length
        }
        let lastCharacterIndex = location + length - 1
        let prefersLineBreakAfterCharacter = prefersInsertingLineBreak(
            afterCharacterAt: lastCharacterIndex,
            in: attributedString
        )
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
        if let lookbackLength = lookbackToFindFirstLineBreakableCharacter(
            startingAt: location + length, 
            in: attributedString,
            maximumLookback: maximumLookback
        ) {
            return length - lookbackLength
        } else {
            return length
        }
    }
}

private extension WordWrappingLineBreakSuggester {
    private func lookbackToFindFirstLineBreakableCharacter(
        startingAt startLocation: Int,
        in attributedString: NSAttributedString,
        maximumLookback: Int
    ) -> Int? {
        var lookback = 0
        var foundWhitespace = false
        while lookback < maximumLookback && !foundWhitespace {
            if prefersInsertingLineBreak(afterCharacterAt: startLocation - lookback, in: attributedString) {
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

    private func prefersInsertingLineBreak(
        afterCharacterAt location: Int,
        in attributedString: NSAttributedString
    ) -> Bool {
        let range = NSRange(location: location, length: 1)
        let attributedSubstring = attributedString.attributedSubstring(from: range)
        let string = attributedSubstring.string.trimmingCharacters(in: .whitespaces)
        return string.isEmpty || CharacterSet(charactersIn: string).isSubset(of: .punctuationCharacters)
    }
}
