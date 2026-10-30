import CoreText
@testable import Runestone
import UIKit
import XCTest

final class HighlightServiceFragmentationTests: XCTestCase {
    func testFragmentsPreserveEndpointsAndStyleAcrossLinesAndCacheInvalidation() throws {
        let stringView = StringView(string: "a😀\r\nbc\r\nd")
        let lines = LineManager(stringView: stringView)
        lines.rebuild()
        let service = HighlightService(lineManager: lines)
        service.highlightedRanges = [HighlightedRange(range: NSRange(location: 1, length: 9), color: .red, cornerRadius: 4)]
        let firstLine = lines.line(atRow: 0)
        let lastLine = lines.line(atRow: 2)
        let firstFragment = makeFragment(index: 0, range: NSRange(location: 0, length: 3))
        let continuation = makeFragment(index: 1, range: NSRange(location: 3, length: 2))
        let lastFragment = makeFragment(index: 2, range: NSRange(location: 0, length: 1))

        let first = try XCTUnwrap(service.highlightedRangeFragments(for: firstFragment, inLineWithID: firstLine.id).first)
        XCTAssertEqual(first.range, NSRange(location: 1, length: 2))
        XCTAssertTrue(first.containsStart)
        XCTAssertFalse(first.containsEnd)
        XCTAssertEqual(first.color, .red)
        XCTAssertEqual(first.cornerRadius, 4)
        let middle = try XCTUnwrap(service.highlightedRangeFragments(for: continuation, inLineWithID: firstLine.id).first)
        XCTAssertEqual(middle.range, NSRange(location: 3, length: 2))
        XCTAssertFalse(middle.containsStart)
        XCTAssertFalse(middle.containsEnd)
        let last = try XCTUnwrap(service.highlightedRangeFragments(for: lastFragment, inLineWithID: lastLine.id).first)
        XCTAssertEqual(last.range, NSRange(location: 0, length: 1))
        XCTAssertFalse(last.containsStart)
        XCTAssertTrue(last.containsEnd)

        service.highlightedRanges = [HighlightedRange(range: NSRange(location: 0, length: 1), color: .blue)]
        let updated = try XCTUnwrap(service.highlightedRangeFragments(for: firstFragment, inLineWithID: firstLine.id).first)
        XCTAssertEqual(updated.range, NSRange(location: 0, length: 1))
        XCTAssertEqual(updated.color, .blue)
        XCTAssertTrue(service.highlightedRangeFragments(for: lastFragment, inLineWithID: lastLine.id).isEmpty)
    }

    private func makeFragment(index: Int, range: NSRange) -> LineFragment {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "test"))
        return LineFragment(id: LineFragmentID(lineId: "test", lineFragmentIndex: index), index: index,
                            visibleRange: range, line: line, descent: 0, baseSize: .zero, scaledSize: .zero, yPosition: 0)
    }
}
