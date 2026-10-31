import CoreText
import Foundation
import RunestoneEngine
import XCTest

final class LineFragmentTests: XCTestCase {
    func testHiddenWhitespaceCaretMappingSurvivesLineReplacement() {
        let text = NSAttributedString(string: "abc  ")
        let line = CTLineCreateWithAttributedString(text)
        let original = LineFragment(id: LineFragmentID(lineId: "line", lineFragmentIndex: 2), index: 2,
                                    visibleRange: NSRange(location: 10, length: 3), line: line,
                                    descent: 2, baseSize: CGSize(width: 30, height: 10),
                                    scaledSize: CGSize(width: 30, height: 15), yPosition: 20)
        let replacement = CTLineCreateWithAttributedString(NSAttributedString(string: "xyz"))
        let fragment = original.withHiddenLength(2).withLine(replacement)

        XCTAssertEqual(fragment.range, NSRange(location: 10, length: 5))
        XCTAssertEqual(fragment.caretLocation(forLineLocalLocation: 10), 10)
        XCTAssertEqual(fragment.caretLocation(forLineLocalLocation: 14), 13)
        XCTAssertEqual(fragment.caretLocation(forLineLocalLocation: 15), 13)
        XCTAssertNil(fragment.caretLocation(forLineLocalLocation: 9))
        XCTAssertNil(fragment.caretLocation(forLineLocalLocation: 16))
        XCTAssertEqual(fragment.caretRange(forLineLocalRange: NSRange(location: 11, length: 4)),
                       NSRange(location: 11, length: 2))
        XCTAssertNil(fragment.caretRange(forLineLocalRange: NSRange(location: 11, length: 5)))
        XCTAssertTrue(fragment.line === replacement)
        XCTAssertEqual(fragment.scaledSize, original.scaledSize)
        XCTAssertEqual(fragment.yPosition, original.yPosition)
    }
}
