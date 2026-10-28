import CoreText
import Foundation
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class LineBreakCompatibilityTests: XCTestCase {
    /// Character classification must not change wrapping around non-ASCII
    /// whitespace/punctuation or accidentally classify a surrogate half as a break.
    func testWhitespaceClassificationPreservesLegacySemantics() {
        var units = (UInt32(0) ... UInt32(UInt16.max)).map { UInt16($0) }
        let source = NSString(characters: &units, length: units.count)
        let attributed = NSAttributedString(string: source as String)
        for index in 0 ..< attributed.length {
            let legacy = attributed.attributedSubstring(from: NSRange(location: index, length: 1)).string
            let legacyWhitespace = legacy.unicodeScalars.allSatisfy { CharacterSet.whitespaces.contains($0) }
            XCTAssertEqual(attributed.isWhitespaceCharacter(at: index), legacyWhitespace, "UTF-16 unit at \(index)")
        }
        XCTAssertFalse(attributed.isWhitespaceCharacter(at: attributed.length))
    }

    func testWordBreaksPreserveLegacyUnicodeAndPunctuationBoundaries() {
        let patterns = [
            String(repeating: "a", count: 140),
            "office cafe\u{301} 😀 👩‍💻 العربية אבג <tag /> /path.file: value; ",
            "a\u{200B}b\u{00A0}c\u{2003}d\tend　句読点、。—«quote» (value) \u{10100}",
            "trailing" + String(repeating: " ", count: 45) + "next\r\n"
        ]
        for pattern in patterns {
            let string = NSMutableAttributedString(string: String(repeating: pattern, count: 4))
            DefaultStringAttributes(textColor: .black, font: .monospacedSystemFont(ofSize: 17, weight: .regular),
                                    kern: 0, tabWidth: 40).apply(to: string)
            let typesetter = CTTypesetterCreateWithAttributedString(string)
            for width in [CGFloat(45), CGFloat(175), CGFloat(10_000)] {
                let suggester = WordWrappingLineBreakSuggester(
                    typesetter: typesetter, attributedString: string, constrainingWidth: width)
                var offset = 0
                while offset < string.length {
                    let expected = legacyWordBreak(typesetter: typesetter, string: string, offset: offset, width: width)
                    XCTAssertEqual(suggester.suggestLineBreak(startingAt: offset), expected,
                                   "Word boundary at UTF-16 offset \(offset), width \(width), pattern \(pattern)")
                    XCTAssertGreaterThan(expected, 0)
                    offset += max(1, expected)
                }
            }
        }
    }

    private func legacyWordBreak(typesetter: CTTypesetter, string: NSAttributedString,
                                 offset: Int, width: CGFloat) -> Int {
        func isBreak(_ location: Int) -> Bool {
            let substring = string.attributedSubstring(from: NSRange(location: location, length: 1))
                .string.trimmingCharacters(in: .whitespaces)
            return substring.isEmpty || CharacterSet(charactersIn: substring).isSubset(of: .punctuationCharacters)
        }
        let length = CTTypesetterSuggestLineBreak(typesetter, offset, Double(width))
        guard offset + length < string.length, !isBreak(offset + length - 1) else {
            return length
        }
        for lookback in 0 ..< min(length, 100) where isBreak(offset + length - lookback) {
            return length - lookback + 1
        }
        return length
    }
}
