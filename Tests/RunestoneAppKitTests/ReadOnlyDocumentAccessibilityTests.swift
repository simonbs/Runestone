#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class ReadOnlyDocumentAccessibilityTests: XCTestCase {
    private let unavailable = NSRange(location: NSNotFound, length: 0)

    func testReadOnlyTextIsExposedUsingUTF16RangesAndNoInventedSelection() {
        let text = "A👩‍💻\r\nB\n"
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: text))
        XCTAssertTrue(view.isAccessibilityElement())
        XCTAssertEqual(view.accessibilityRole(), .staticText)
        XCTAssertEqual(view.accessibilityValue() as? String, text)
        XCTAssertEqual(view.accessibilityNumberOfCharacters(), (text as NSString).length)
        XCTAssertEqual(view.accessibilityString(for: NSRange(location: 1, length: 5)), "👩‍💻")
        XCTAssertEqual(view.accessibilityString(for: NSRange(location: 6, length: 2)), "\r\n")
        XCTAssertEqual(view.accessibilityRange(for: 2), NSRange(location: 1, length: 5))
        XCTAssertEqual(view.accessibilitySelectedTextRange(), unavailable)
        XCTAssertNil(view.accessibilitySelectedText())
        for selector in ["accessibilityValue", "accessibilityStringForRange:", "accessibilityLineForIndex:",
                         "accessibilityRangeForLine:", "accessibilityFrameForRange:"] {
            XCTAssertTrue(view.isAccessibilitySelectorAllowed(NSSelectorFromString(selector)), selector)
        }
        XCTAssertFalse(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilityValue:")))
        XCTAssertFalse(view.isAccessibilitySelectorAllowed(NSSelectorFromString("setAccessibilitySelectedTextRange:")))
    }

    func testLineRangesIncludeCRLFAndFinalEmptyLine() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "A👩‍💻\r\nB\n"))
        XCTAssertEqual(view.accessibilityLine(for: 0), 0)
        XCTAssertEqual(view.accessibilityLine(for: 6), 0)
        XCTAssertEqual(view.accessibilityLine(for: 8), 1)
        XCTAssertEqual(view.accessibilityLine(for: 10), 2)
        XCTAssertEqual(view.accessibilityRange(forLine: 0), NSRange(location: 0, length: 8))
        XCTAssertEqual(view.accessibilityRange(forLine: 1), NSRange(location: 8, length: 2))
        XCTAssertEqual(view.accessibilityRange(forLine: 2), NSRange(location: 10, length: 0))
        XCTAssertEqual(view.accessibilityRange(forLine: 3), unavailable)
        XCTAssertEqual(view.accessibilityRange(forLine: -1), unavailable)
        XCTAssertEqual(view.accessibilityLine(for: 11), NSNotFound)
    }

    func testInvalidRangesAndDetachedGeometryAreUnavailable() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: "A😀B"))
        XCTAssertNil(view.accessibilityString(for: NSRange(location: 2, length: 1)))
        XCTAssertNil(view.accessibilityString(for: NSRange(location: 0, length: Int.max)))
        XCTAssertNil(view.accessibilityString(for: NSRange(location: NSNotFound, length: 0)))
        XCTAssertEqual(view.accessibilityRange(for: -1), unavailable)
        XCTAssertEqual(view.accessibilityRange(for: NSNotFound), unavailable)
        XCTAssertEqual(view.accessibilityVisibleCharacterRange(), unavailable)
        XCTAssertEqual(view.accessibilityRange(for: NSPoint.zero), unavailable)
        XCTAssertEqual(view.accessibilityFrame(for: NSRange(location: 0, length: 1)), .zero)
    }

    func testEmptyDocumentAndRetirementDoNotExposeStaleText() {
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: ""))
        XCTAssertEqual(view.accessibilityValue() as? String, "")
        XCTAssertEqual(view.accessibilityNumberOfCharacters(), 0)
        XCTAssertEqual(view.accessibilityString(for: NSRange(location: 0, length: 0)), "")
        XCTAssertEqual(view.accessibilityRange(forLine: 0), NSRange(location: 0, length: 0))
        view.setContent(NSAttributedString(string: "private"))
        XCTAssertEqual(view.accessibilityValue() as? String, "private")
        view.retireInputView()
        XCTAssertFalse(view.isAccessibilityElement())
        XCTAssertNil(view.accessibilityValue())
        XCTAssertNil(view.accessibilityString(for: NSRange(location: 0, length: 1)))
        XCTAssertEqual(view.accessibilitySelectedTextRange(), unavailable)
        XCTAssertEqual(view.accessibilityVisibleCharacterRange(), unavailable)
    }
}
#endif
