@testable import Runestone
import XCTest

@available(iOS 16, *)
final class UITextSearchingHelperTests: XCTestCase {
    func testDecorationsAreBatchedAndKeepUnrelatedHighlights() {
        let textView = TextView()
        textView.text = String(repeating: "a", count: 1_001)
        let existing = HighlightedRange(range: NSRange(location: 1_000, length: 1), color: .red)
        textView.highlightedRanges = [existing]
        let helper = UITextSearchingHelper()
        helper.textView = textView

        for location in 0 ..< 1_000 {
            helper.decorate(foundTextRange: IndexedRange(NSRange(location: location, length: 1)), document: nil, usingStyle: .found)
        }
        // Rebuilding highlights for each callback is quadratic in the number of matches.
        XCTAssertEqual(textView.highlightedRanges, [existing])
        let applied = expectation(description: "Decoration batch applied")
        DispatchQueue.main.async {
            XCTAssertEqual(textView.highlightedRanges.count, 1_001)
            XCTAssertEqual(textView.highlightedRanges.first, existing)
            XCTAssertEqual(textView.highlightedRanges.last?.range, NSRange(location: 999, length: 1))
            applied.fulfill()
        }
        wait(for: [applied], timeout: 2)
    }

    func testLatestStyleWinsAndNormalRemovesDecoration() {
        let textView = TextView()
        textView.text = "abc"
        textView.editorDelegate = self
        let helper = UITextSearchingHelper()
        helper.textView = textView
        let first = IndexedRange(NSRange(location: 0, length: 1))
        let second = IndexedRange(NSRange(location: 1, length: 1))
        textView.highlightedRanges = [HighlightedRange(range: second.range, color: .red)]
        helper.decorate(foundTextRange: first, document: nil, usingStyle: .found)
        helper.decorate(foundTextRange: first, document: nil, usingStyle: .highlighted)
        helper.decorate(foundTextRange: second, document: nil, usingStyle: .normal)

        XCTAssertTrue(helper.shouldReplace(foundTextRange: first, document: nil, withText: "x"))
        XCTAssertFalse(helper.shouldReplace(foundTextRange: second, document: nil, withText: "x"))
        let applied = expectation(description: "Latest decorations applied")
        DispatchQueue.main.async {
            XCTAssertEqual(textView.highlightedRanges.count, 1)
            XCTAssertEqual(textView.highlightedRanges.first?.range, first.range)
            let expected = textView.theme.highlightedRange(forFoundTextRange: first.range, ofStyle: .highlighted)
            XCTAssertEqual(textView.highlightedRanges.first?.color, expected?.color)
            applied.fulfill()
        }
        wait(for: [applied], timeout: 2)
    }

    func testDocumentReplacementDiscardsPendingDecorations() {
        let textView = TextView()
        textView.text = "abcdef"
        let helper = UITextSearchingHelper()
        helper.textView = textView
        helper.decorate(foundTextRange: IndexedRange(NSRange(location: 5, length: 1)), document: nil, usingStyle: .found)
        textView.text = "a"

        let applied = expectation(description: "Stale decoration discarded")
        DispatchQueue.main.async {
            XCTAssertTrue(textView.highlightedRanges.isEmpty)
            applied.fulfill()
        }
        wait(for: [applied], timeout: 2)
    }

    func testDisablingFindDiscardsPendingDecorations() {
        let textView = TextView()
        textView.text = "abc"
        let helper = UITextSearchingHelper()
        helper.textView = textView
        helper.isFindInteractionEnabled = true
        helper.decorate(foundTextRange: IndexedRange(NSRange(location: 0, length: 1)), document: nil, usingStyle: .found)
        helper.isFindInteractionEnabled = false

        let applied = expectation(description: "Disabled decoration discarded")
        DispatchQueue.main.async {
            XCTAssertTrue(textView.highlightedRanges.isEmpty)
            applied.fulfill()
        }
        wait(for: [applied], timeout: 2)
    }

    func testClearingDiscardsPendingDecorations() {
        let textView = TextView()
        textView.text = "abc"
        let helper = UITextSearchingHelper()
        helper.textView = textView
        helper.decorate(foundTextRange: IndexedRange(NSRange(location: 0, length: 1)), document: nil, usingStyle: .found)
        helper.clearAllDecoratedFoundText()

        let applied = expectation(description: "Pending callback completed")
        DispatchQueue.main.async {
            XCTAssertTrue(textView.highlightedRanges.isEmpty)
            applied.fulfill()
        }
        wait(for: [applied], timeout: 2)
    }
}

@available(iOS 16, *)
extension UITextSearchingHelperTests: TextViewDelegate {
    func textView(_ textView: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        true
    }
}
