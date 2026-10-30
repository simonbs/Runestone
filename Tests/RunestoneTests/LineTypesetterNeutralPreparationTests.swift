import CoreText
@testable import Runestone
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
}
