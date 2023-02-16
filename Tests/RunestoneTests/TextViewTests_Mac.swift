#if os(macOS)
import AppKit
import Runestone
import XCTest

final class TextViewTestsMac: XCTestCase {
    func testMovingInDocument() throws {
        let textView = makeTextView(withText: "Hello,\nWorld")
        // moveToEndOfParagraph:
        textView.keyDown(with: try .keyEvent(pressing: "e", withModifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
        // moveLeft:
        textView.keyDown(with: try .keyEvent(pressing: .leftArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
        // moveRight:
        textView.keyDown(with: try .keyEvent(pressing: .rightArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
        // moveToBeginningOfParagraph:
        textView.keyDown(with: try .keyEvent(pressing: "a", withModifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        // moveDown:
        textView.keyDown(with: try .keyEvent(pressing: "n", withModifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
        // moveUp:
        textView.keyDown(with: try .keyEvent(pressing: "p", withModifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        // moveDown:
        textView.keyDown(with: try .keyEvent(pressing: .downArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
        // moveUp:
        textView.keyDown(with: try .keyEvent(pressing: .upArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
    }
}

private extension TextViewTestsMac {
    private func makeTextView(withText text: String) -> TextView {
        let textView = TextView()
        textView.text = text
        textView.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        return textView
    }
}
#endif
