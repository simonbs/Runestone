import CoreText
import Foundation

/// Suggests a UTF-16 line break using the shared Core Text wrapping policy.
public struct CharacterLineBreakSuggester {
    let typesetter: CTTypesetter
    let attributedString: NSAttributedString
    let constrainingWidth: CGFloat

    /// Creates a suggester for the prepared text and its Core Text typesetter.
    public init(typesetter: CTTypesetter, attributedString: NSAttributedString, constrainingWidth: CGFloat) {
        self.typesetter = typesetter
        self.attributedString = attributedString
        self.constrainingWidth = constrainingWidth
    }

    /// Returns the suggested number of UTF-16 units, or zero when no cluster fits.
    /// The caller must still ensure that the final break respects composed-character boundaries.
    public func suggestLineBreak(startingAt startOffset: Int) -> Int {
        let length = CTTypesetterSuggestClusterBreak(typesetter, startOffset, Double(constrainingWidth))
        guard length > 0 else {
            // LineTypesetter will force one complete grapheme when none fits.
            return 0
        }
        guard startOffset + length < attributedString.length else {
            // There is no character after suggested line break.
            return length
        }
        let lastCharacterIndex = startOffset + length - 1
        let range = NSRange(location: lastCharacterIndex, length: 2)
        if attributedString.attributedSubstring(from: range).string == "\r\n" {
            // Suggested line break is in the middle of CRLF so return one position ahead which is after the character pair.
            return length + 1
        }
        return length
    }
}
