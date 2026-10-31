import CoreText
import RunestoneEngine
import XCTest

final class LineBreakSuggesterTests: XCTestCase {
    func testWordBreaksMatchLegacyUnicodeAndPunctuationPolicy() {
        let patterns = ["office cafe\u{301} 😀 👩‍💻 العربية אבג <tag /> /path.file: value; ",
                        "a\u{200B}b\u{00A0}c\u{2003}d\tend　句読点、。—«quote» (value) \u{10100}",
                        String(repeating: "a", count: 140)]
        for pattern in patterns {
            let string = NSAttributedString(string: String(repeating: pattern, count: 3), attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 17, nil)
            ])
            let typesetter = CTTypesetterCreateWithAttributedString(string)
            for width in [CGFloat(45), 175, 10_000] {
                let suggester = WordWrappingLineBreakSuggester(typesetter: typesetter, attributedString: string, constrainingWidth: width)
                var offset = 0
                while offset < string.length {
                    let expected = legacyWordBreak(typesetter: typesetter, string: string, offset: offset, width: width)
                    XCTAssertEqual(suggester.suggestLineBreak(startingAt: offset), expected)
                    XCTAssertGreaterThan(expected, 0)
                    offset += max(1, expected)
                }
            }
        }
    }

    func testCharacterWrappingPreservesCRLFAndCoreTextClusterBreaks() {
        let string = NSAttributedString(string: "abc😀e\u{301}\r\nnext", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 17, nil)
        ])
        let typesetter = CTTypesetterCreateWithAttributedString(string)
        for width in [CGFloat(1), 8, 17, 30, 80, 1000] {
            let suggester = CharacterLineBreakSuggester(typesetter: typesetter, attributedString: string, constrainingWidth: width)
            for offset in [0, 3, 5, 7] {
                let native = CTTypesetterSuggestClusterBreak(typesetter, offset, Double(width))
                var expected = native
                if native > 0 && offset + native < string.length &&
                    string.attributedSubstring(from: NSRange(location: offset + native - 1, length: 2)).string == "\r\n" {
                    expected += 1
                }
                let suggested = suggester.suggestLineBreak(startingAt: offset)
                XCTAssertEqual(suggested, expected)
                if suggested > 0 {
                    XCTAssertNotEqual(offset + suggested, 8, "A character break must not split CRLF.")
                }
            }
        }
    }

    private func legacyWordBreak(typesetter: CTTypesetter, string: NSAttributedString, offset: Int, width: CGFloat) -> Int {
        func isBreak(_ location: Int) -> Bool {
            let substring = string.attributedSubstring(from: NSRange(location: location, length: 1))
                .string.trimmingCharacters(in: .whitespaces)
            return substring.isEmpty || CharacterSet(charactersIn: substring).isSubset(of: .punctuationCharacters)
        }
        let length = CTTypesetterSuggestLineBreak(typesetter, offset, Double(width))
        guard length > 0, offset + length < string.length, !isBreak(offset + length - 1) else { return length }
        for lookback in 0 ..< min(length, 100) where isBreak(offset + length - lookback) {
            return length - lookback + 1
        }
        return length
    }
}
