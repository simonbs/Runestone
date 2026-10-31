import CoreText
import RunestoneEngine
import XCTest

final class LineTypesetterNeutralPreparationTests: XCTestCase {
    func testFallbackWrapsUnicodeWithoutSplittingOrLosingText() {
        let text = "alpha cafe\u{301} 😀 beta\r\n" as NSString
        let input = NSAttributedString(string: text as String, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 18, nil)
        ])
        for mode in [LineBreakMode.byWordWrapping, .byCharWrapping] {
            let typesetter = LineTypesetter(lineID: "neutral", preparation: DefaultLineTypesetterPreparation())
            typesetter.lineBreakMode = mode
            typesetter.constrainingWidth = 48
            typesetter.prepareToTypeset(input)
            typesetter.typesetLineFragments(toLocation: input.length)
            XCTAssertTrue(typesetter.isFinishedTypesetting)
            XCTAssertGreaterThan(typesetter.lineFragments.count, 1)
            var reconstructed = ""
            var nextLocation = 0
            for fragment in typesetter.lineFragments {
                let range = fragment.range
                XCTAssertEqual(range.location, nextLocation)
                XCTAssertEqual(text.rangeOfComposedCharacterSequences(for: range), range)
                reconstructed += text.substring(with: range)
                nextLocation = NSMaxRange(range)
            }
            XCTAssertEqual(nextLocation, input.length)
            XCTAssertEqual(reconstructed, text as String)
        }
    }

    func testFallbackRepreparationDoesNotReuseOldFragments() {
        let font = CTFontCreateWithName("Menlo" as CFString, 18, nil)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let old = NSAttributedString(string: String(repeating: "old text ", count: 600), attributes: attributes)
        let new = NSAttributedString(string: String(repeating: "new text ", count: 600), attributes: attributes)
        let typesetter = LineTypesetter(lineID: "neutral", preparation: DefaultLineTypesetterPreparation())
        typesetter.constrainingWidth = 100
        typesetter.prepareToTypeset(old)
        typesetter.typesetLineFragments(toLocation: old.length)
        let oldFragmentCount = typesetter.lineFragments.count
        let reused = typesetter.reprepareToTypeset(new, previous: old, prefixLimit: oldFragmentCount)
        XCTAssertTrue(reused.isEmpty)
        typesetter.typesetLineFragments(toLocation: new.length)
        XCTAssertTrue(typesetter.isFinishedTypesetting)
        XCTAssertEqual(typesetter.lineFragments.last.map { NSMaxRange($0.range) }, new.length)
    }

    func testIncrementalLayoutContinuesAfterAppearanceRefresh() throws {
        let font = CTFontCreateWithName("Menlo" as CFString, 18, nil)
        let text = "alpha beta gamma delta epsilon zeta eta theta" as NSString
        let input = NSAttributedString(string: text as String, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ])
        let typesetter = LineTypesetter(lineID: "incremental", preparation: DefaultLineTypesetterPreparation())
        typesetter.constrainingWidth = 65
        typesetter.prepareToTypeset(input)
        typesetter.typesetLineFragments(toLocation: 1)
        let first = try XCTUnwrap(typesetter.lineFragments.first)
        XCTAssertFalse(typesetter.isFinishedTypesetting)
        let consumed = typesetter.typesetLength

        let updated = NSMutableAttributedString(attributedString: input)
        updated.addAttribute(NSAttributedString.Key(kCTForegroundColorAttributeName as String),
                             value: CGColor(gray: 0.5, alpha: 1), range: NSRange(location: 0, length: input.length))
        let refreshed = typesetter.refreshAppearance(updated)
        let rebuilt = try XCTUnwrap(refreshed.first)
        XCTAssertEqual(rebuilt.range, first.range)
        XCTAssertEqual(rebuilt.yPosition, first.yPosition)
        XCTAssertFalse(rebuilt.line === first.line)
        XCTAssertEqual(typesetter.typesetLength, consumed)

        typesetter.typesetLineFragments(toLocation: input.length)
        XCTAssertTrue(typesetter.isFinishedTypesetting)
        var next = 0
        for fragment in typesetter.lineFragments {
            XCTAssertEqual(fragment.range.location, next)
            next = fragment.range.upperBound
        }
        XCTAssertEqual(next, text.length)
    }
}
