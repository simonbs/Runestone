import CoreText
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class LineTypesetterProgressTests: XCTestCase {
    /// A width below one glyph must consume a complete first grapheme rather than
    /// decrement into zero/negative CoreText ranges or split its UTF-16 sequence.
    func testNarrowPositiveWidthPreservesWholeGraphemesAndMakesProgress() throws {
        for mode in LineBreakMode.allCases {
            for grapheme in ["W", "e\u{301}", "😀", "👨‍👩‍👧‍👦"] {
                let text = attributedText(grapheme + "W")
                let typesetter = makeTypesetter(text, width: 1, mode: mode)
                typesetter.typesetLineFragments(toLocation: text.length)
                assertCompleteLayout(typesetter, text: text)
                let first = try XCTUnwrap(typesetter.lineFragments.first)
                XCTAssertEqual(first.visibleRange, NSRange(location: 0, length: grapheme.utf16.count),
                               "mode=\(mode), grapheme=\(grapheme)")
                XCTAssertGreaterThan(first.baseSize.width, typesetter.constrainingWidth,
                                     "The complete first grapheme must overflow this deliberately narrow width.")
            }
        }
    }

    /// Word lookback can select the punctuation scalar inside a keycap even
    /// when a complete keycap fits. Preserve its composed boundary without overflow.
    func testOrdinaryWidthKeepsKeycapIntactAndFitsContainer() throws {
        let keycap = "#️⃣"
        let text = attributedText(keycap + "BBBBBBBB")
        let keycapRange = NSRange(location: 0, length: keycap.utf16.count)
        for mode in LineBreakMode.allCases {
            let typesetter = makeTypesetter(text, width: 160, mode: mode)
            typesetter.typesetLineFragments(toLocation: text.length)
            assertCompleteLayout(typesetter, text: text)
            let first = try XCTUnwrap(typesetter.lineFragments.first)
            XCTAssertEqual(NSIntersectionRange(first.visibleRange, keycapRange), keycapRange,
                           "The first fragment must contain the whole keycap, mode=\(mode).")
            XCTAssertLessThanOrEqual(first.baseSize.width, typesetter.constrainingWidth,
                                     "This ordinary-width case must fit without the oversized-grapheme fallback, mode=\(mode).")
        }
    }

    /// Character wrapping already repairs a suggested CRLF split. Narrow-width
    /// truncation must not undo that repair or lose the zero-advance terminator.
    func testNarrowWidthKeepsCRLFTogetherInBothModes() {
        for mode in LineBreakMode.allCases {
            for source in ["\r\n", "W\r\n", "WW\r\n"] {
                let text = attributedText(source)
                let typesetter = makeTypesetter(text, width: 1, mode: mode)
                typesetter.typesetLineFragments(toLocation: text.length)
                assertCompleteLayout(typesetter, text: text)
                let terminator = (source as NSString).range(of: "\r\n")
                XCTAssertTrue(typesetter.lineFragments.contains { fragment in
                    NSIntersectionRange(fragment.visibleRange, terminator) == terminator
                }, "The complete CRLF must belong to one visible fragment, mode=\(mode).")
            }
        }
    }

    /// A space carrying a combining mark is visible content. Hiding just its first
    /// code unit leaves the mark detached; hiding the whole cluster loses content.
    func testHiddenWhitespaceDoesNotSplitOrDiscardSpaceWithCombiningMark() {
        for mode in LineBreakMode.allCases {
            for source in ["W \u{301}W", "W  \u{301}W"] {
                let text = attributedText(source)
                let typesetter = makeTypesetter(text, width: 1, mode: mode)
                typesetter.typesetLineFragments(toLocation: text.length)
                assertCompleteLayout(typesetter, text: text)
                let markedSpace = (source as NSString).range(of: " \u{301}")
                XCTAssertTrue(typesetter.lineFragments.contains { fragment in
                    NSIntersectionRange(fragment.visibleRange, markedSpace) == markedSpace
                }, "The marked space must remain visible as one grapheme, mode=\(mode).")
            }
        }
    }

    /// A temporarily unavailable width must leave the prepared text intact so a
    /// later layout can consume it, rather than producing a bogus empty fragment.
    func testNonpositiveWidthDoesNotConsumeTextAndCanResume() {
        let text = attributedText("W😀\r\n")
        for mode in LineBreakMode.allCases {
            for width in [CGFloat(0), -1] {
                let typesetter = makeTypesetter(text, width: width, mode: mode)
                XCTAssertTrue(typesetter.typesetLineFragments(toLocation: text.length).isEmpty)
                XCTAssertTrue(typesetter.lineFragments.isEmpty)
                XCTAssertEqual(typesetter.typesetLength, 0)
                XCTAssertFalse(typesetter.isFinishedTypesetting)
                typesetter.constrainingWidth = 320
                typesetter.typesetLineFragments(toLocation: text.length)
                assertCompleteLayout(typesetter, text: text)
            }
        }
    }

    private func attributedText(_ source: String) -> NSAttributedString {
        let text = NSMutableAttributedString(string: source)
        DefaultStringAttributes(textColor: .black, font: .systemFont(ofSize: 80), kern: 0, tabWidth: 40).apply(to: text)
        return text
    }

    private func makeTypesetter(_ text: NSAttributedString, width: CGFloat, mode: LineBreakMode) -> LineTypesetter {
        let typesetter = LineTypesetter(lineID: "narrow-width-progress")
        typesetter.lineBreakMode = mode
        typesetter.constrainingWidth = width
        typesetter.prepareToTypeset(text)
        return typesetter
    }

    private func assertCompleteLayout(_ typesetter: LineTypesetter, text: NSAttributedString,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(typesetter.isFinishedTypesetting, file: file, line: line)
        XCTAssertEqual(typesetter.typesetLength, text.length, file: file, line: line)
        // Swift Character boundaries provide an independent oracle for the
        // production NSString composed-sequence helper, including CRLF and ZWJ.
        var boundaries: Set<Int> = [0]
        var boundary = 0
        for character in text.string {
            boundary += String(character).utf16.count
            boundaries.insert(boundary)
        }
        var consumed = 0
        for fragment in typesetter.lineFragments {
            XCTAssertGreaterThan(fragment.visibleRange.length, 0, file: file, line: line)
            XCTAssertEqual(fragment.range.location, consumed, file: file, line: line)
            XCTAssertTrue(boundaries.contains(fragment.visibleRange.location), file: file, line: line)
            XCTAssertTrue(boundaries.contains(fragment.visibleRange.upperBound), file: file, line: line)
            XCTAssertTrue(boundaries.contains(fragment.range.upperBound), file: file, line: line)
            let coreTextRange = CTLineGetStringRange(fragment.line)
            XCTAssertEqual(coreTextRange.location, fragment.visibleRange.location, file: file, line: line)
            XCTAssertEqual(coreTextRange.length, fragment.visibleRange.length, file: file, line: line)
            consumed = fragment.range.upperBound
        }
        XCTAssertEqual(consumed, text.length, file: file, line: line)
    }
}
