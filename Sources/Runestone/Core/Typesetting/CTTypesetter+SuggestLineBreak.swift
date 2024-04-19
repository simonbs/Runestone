import CoreText
import Foundation

extension CTTypesetter {
    func suggestLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        using lineBreakMode: LineBreakMode,
        maximumLineFragmentWidth: CGFloat
    ) -> Int {
        let length = switch lineBreakMode {
        case .byWordWrapping:
            suggestWordWrappingLineBreak(
                after: location,
                in: attributedString,
                maximumLineFragmentWidth: maximumLineFragmentWidth
            )
        case .byCharWrapping:
            suggestCharacterLineBreak(
                after: location,
                in: attributedString,
                maximumLineFragmentWidth: maximumLineFragmentWidth
            )
        }
        return trimLength(length, fromLocation: location, toFitWidth: maximumLineFragmentWidth)
    }
}

// MARK: -
private extension CTTypesetter {
    func trimLength(
        _ suggestedLength: Int,
        fromLocation location: Int,
        toFitWidth maximumLineFragmentWidth: CGFloat
    ) -> Int {
        // CTTypesetterSuggestLineBreak may return lines that are wider than than the supplied maximum width.
        // In that case we keep removing charactears from the line until the width of the line is below the maximum width.
        var length = suggestedLength
        let range = CFRangeMake(location, length)
        let line = CTTypesetterCreateLine(self, range)
        var width = CTLineGetTypographicBounds(line, nil, nil, nil)
        while length > 0 && width > maximumLineFragmentWidth {
            length -= 1
            let range = CFRangeMake(location, length)
            let line = CTTypesetterCreateLine(self, range)
            width = CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        return length
    }
}

// MARK: - Character
private extension CTTypesetter {
    private func suggestCharacterLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        maximumLineFragmentWidth: CGFloat
    ) -> Int {
        let length = CTTypesetterSuggestClusterBreak(
            self,
            location,
            Double(maximumLineFragmentWidth)
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

// MARK: - Word Wrapping
private extension CTTypesetter {
    private func suggestWordWrappingLineBreak(
        after location: Int,
        in attributedString: NSAttributedString,
        maximumLineFragmentWidth: CGFloat
    ) -> Int {
        let length = CTTypesetterSuggestLineBreak(
            self,
            location,
            Double(maximumLineFragmentWidth)
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
