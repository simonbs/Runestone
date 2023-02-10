#if os(macOS)
import XCTest
import AppKit
import Runestone

class TextView_MacTests: XCTestCase {
    func testMovingInDocument() throws {
        let textView = createTextView(text: "Hello,\nWorld")

        // moveToEndOfParagraph:
        textView.keyDown(with: try .create(characters: "e", modifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
        // moveLeft:
        textView.keyDown(with: try .create(key: .leftArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
        // moveRight:
        textView.keyDown(with: try .create(key: .rightArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
        // moveToBeginningOfParagraph:
        textView.keyDown(with: try .create(characters: "a", modifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        // moveDown:
        textView.keyDown(with: try .create(characters: "n", modifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
        // moveUp:
        textView.keyDown(with: try .create(characters: "p", modifiers: .control))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        // moveDown:
        textView.keyDown(with: try .create(key: .downArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
        // moveUp:
        textView.keyDown(with: try .create(key: .upArrow))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
    }


    private func createTextView(text: String, selectedRange: NSRange = NSRange(location: 0, length: 0)) -> TextView {
        let textView = TextView()
        textView.text = text
        textView.frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        return textView
    }
}
#endif
