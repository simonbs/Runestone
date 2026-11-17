#if canImport(AppKit)
import AppKit
import XCTest
@testable import RunestoneAppKit

final class PreparedInputTextCheckingAnnotationsTests: XCTestCase {
    func testAnnotationsAreAppliedWithoutChangingCanonicalText() {
        let annotations = PreparedInputTextCheckingAnnotations()
        let key = NSAttributedString.Key.spellingState
        annotations.set([key: "1"], range: NSRange(location: 1, length: 3), textLength: 5)

        let canonical = NSAttributedString(string: "hello")
        let presentation = NSMutableAttributedString(attributedString: canonical)
        annotations.apply(to: presentation, documentRange: NSRange(location: 0, length: 5))

        XCTAssertEqual(canonical.string, "hello")
        XCTAssertNil(canonical.attribute(key, at: 2, effectiveRange: nil))
        XCTAssertEqual(presentation.attribute(key, at: 2, effectiveRange: nil) as? String, "1")
    }

    func testOutOfBoundsAnnotationIsClampedToDocument() {
        let annotations = PreparedInputTextCheckingAnnotations()
        let key = NSAttributedString.Key.spellingState
        annotations.add([key: "1"], range: NSRange(location: 3, length: 99), textLength: 5)
        let presentation = NSMutableAttributedString(string: "hello")

        annotations.apply(to: presentation, documentRange: NSRange(location: 0, length: 5))

        XCTAssertNil(presentation.attribute(key, at: 2, effectiveRange: nil))
        XCTAssertEqual(presentation.attribute(key, at: 4, effectiveRange: nil) as? String, "1")
    }

    func testSpellingRangesExcludeOtherNativeAnnotations() {
        let annotations = PreparedInputTextCheckingAnnotations()
        let spelling = NSRange(location: 0, length: 3)
        annotations.add([.spellingState: String(NSAttributedString.SpellingState.spelling.rawValue)],
                        range: spelling, textLength: 7)
        annotations.add([.spellingState: String(NSAttributedString.SpellingState.grammar.rawValue)],
                        range: NSRange(location: 4, length: 3), textLength: 7)
        XCTAssertEqual(annotations.spellingRanges, [spelling])
    }

    func testNotFoundRangeMeansWholeDocument() {
        XCTAssertEqual(PreparedInputTextCheckingAnnotations.clamp(
            NSRange(location: NSNotFound, length: 0), textLength: 7
        ), NSRange(location: 0, length: 7))
    }
}
#endif
