@testable import Runestone
import XCTest

final class MarkedCharacterPairTests: XCTestCase {
    func testMarkedQuoteComposesWithoutInsertingCharacterPair() throws {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.characterPairs = [QuotePair()]
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.selectedRange = NSRange(location: 0, length: 0)
        input.setMarkedText("'", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(view.text, "'")
        XCTAssertNotNil(view.markedTextRange)
        input.insertText("ó")
        XCTAssertEqual(view.text, "ó")
        XCTAssertNil(view.markedTextRange)
        XCTAssertEqual(view.selectedRange, NSRange(location: 1, length: 0))
    }

    func testOrdinaryQuoteStillInsertsPair() {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.characterPairs = [QuotePair()]
        view.selectedRange = NSRange(location: 0, length: 0)
        view.insertText("'")
        XCTAssertEqual(view.text, "''")
        XCTAssertEqual(view.selectedRange, NSRange(location: 1, length: 0))
    }
}

private struct QuotePair: CharacterPair {
    let leading = "'"
    let trailing = "'"
}
