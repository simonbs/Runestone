import CoreText
import RunestoneEngine
import XCTest

final class LogicalLineLayoutTests: XCTestCase {
    func testIncrementalRequestsAndHeightUseMeasuredFragments() throws {
        let text = NSAttributedString(string: String(repeating: "alpha beta ", count: 50), attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 18, nil)
        ])
        let typesetter = LineTypesetter(lineID: "line", preparation: DefaultLineTypesetterPreparation())
        typesetter.constrainingWidth = 80
        typesetter.lineFragmentHeightMultiplier = 1.5
        typesetter.prepareToTypeset(text)
        XCTAssertEqual(typesetter.estimatedLineHeight(fragmentHeight: 20), 30)

        let first = try XCTUnwrap(typesetter.typeset(.toLineFragmentIndex(0)).first)
        let initialCount = typesetter.lineFragments.count
        XCTAssertGreaterThanOrEqual(initialCount, 1)
        XCTAssertGreaterThan(typesetter.estimatedLineHeight(fragmentHeight: 20), first.scaledSize.height)
        XCTAssertTrue(typesetter.typeset(.toLineFragmentIndex(0)).isEmpty)
        XCTAssertEqual(typesetter.reusablePrefixLimit(for: .toLineFragmentIndex(initialCount)), initialCount)

        let oldCount = typesetter.lineFragments.count
        let lastKnown = try XCTUnwrap(typesetter.lineFragments.last)
        let added = typesetter.typeset(.toLocation(lastKnown.range.upperBound))
        XCTAssertGreaterThanOrEqual(added.count, 1)
        XCTAssertEqual(typesetter.lineFragments.count, oldCount + added.count)
        XCTAssertEqual(typesetter.reusablePrefixLimit(for: .toLocation(first.range.upperBound)), 0)
        typesetter.typeset(.toLocation(text.length))
        let last = try XCTUnwrap(typesetter.lineFragments.last)
        XCTAssertTrue(typesetter.isFinishedTypesetting)
        XCTAssertEqual(typesetter.estimatedLineHeight(fragmentHeight: 20), last.yPosition + last.scaledSize.height, accuracy: 0.001)
    }

    func testRectRequestAndEmptyOrUnmeasuredLines() throws {
        let typesetter = LineTypesetter(lineID: "line", preparation: DefaultLineTypesetterPreparation())
        typesetter.lineFragmentHeightMultiplier = 2
        typesetter.prepareToTypeset(NSAttributedString(string: ""))
        XCTAssertEqual(typesetter.estimatedLineHeight(fragmentHeight: 12), 24)
        XCTAssertTrue(typesetter.typeset(.inRect(CGRect(x: 0, y: 0, width: 50, height: 100))).isEmpty)

        typesetter.reset()
        let text = NSAttributedString(string: String(repeating: "word ", count: 50), attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 18, nil)
        ])
        typesetter.prepareToTypeset(text)
        XCTAssertTrue(typesetter.typeset(.toLocation(1)).isEmpty)
        XCTAssertEqual(typesetter.estimatedLineHeight(fragmentHeight: 12), 24)
        typesetter.constrainingWidth = 80
        let fragments = typesetter.typeset(.inRect(CGRect(x: 0, y: 0, width: 80, height: 1)))
        let first = try XCTUnwrap(fragments.first)
        XCTAssertEqual(fragments.count, 1)
        let boundary = first.yPosition + first.scaledSize.height
        XCTAssertEqual(typesetter.reusablePrefixLimit(for: .inRect(CGRect(x: 0, y: 0, width: 80, height: boundary))), 0)
        XCTAssertEqual(typesetter.reusablePrefixLimit(for: .inRect(CGRect(x: 0, y: 0, width: 80, height: boundary + 1))), 1)
    }
}
