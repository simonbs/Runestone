import RunestoneEngine
import XCTest

final class HighlightRangeSliceTests: XCTestCase {
    func testClippingAcrossLinesAndWrappedFragmentsRetainsOnlyOriginalEndpoints() throws {
        // UTF-16 positions in "a😀\r\nbc\r\nd": selection starts at the emoji and ends after "d".
        let source = HighlightRangeSlice(range: NSRange(location: 1, length: 9), containsStart: true, containsEnd: true)
        let firstLine = try XCTUnwrap(source.clipped(to: NSRange(location: 0, length: 5), localize: true))
        let middleLine = try XCTUnwrap(source.clipped(to: NSRange(location: 5, length: 4), localize: true))
        let lastLine = try XCTUnwrap(source.clipped(to: NSRange(location: 9, length: 1), localize: true))
        XCTAssertEqual(firstLine, HighlightRangeSlice(range: NSRange(location: 1, length: 4),
                                                      containsStart: true, containsEnd: false))
        XCTAssertEqual(middleLine, HighlightRangeSlice(range: NSRange(location: 0, length: 4),
                                                       containsStart: false, containsEnd: false))
        XCTAssertEqual(lastLine, HighlightRangeSlice(range: NSRange(location: 0, length: 1),
                                                     containsStart: false, containsEnd: true))

        XCTAssertEqual(firstLine.clipped(to: NSRange(location: 0, length: 3)),
                       HighlightRangeSlice(range: NSRange(location: 1, length: 2), containsStart: true, containsEnd: false))
        XCTAssertEqual(firstLine.clipped(to: NSRange(location: 3, length: 2)),
                       HighlightRangeSlice(range: NSRange(location: 3, length: 2), containsStart: false, containsEnd: false))
    }

    func testClippingPreservesEndAndRejectsDisjointOrEmptyRanges() {
        let source = HighlightRangeSlice(range: NSRange(location: 3, length: 4), containsStart: true, containsEnd: true)
        XCTAssertEqual(source.clipped(to: NSRange(location: 5, length: 4)),
                       HighlightRangeSlice(range: NSRange(location: 5, length: 2), containsStart: false, containsEnd: true))
        XCTAssertNil(source.clipped(to: NSRange(location: 0, length: 3)))
        XCTAssertNil(source.clipped(to: NSRange(location: 7, length: 2)))
        XCTAssertNil(source.clipped(to: NSRange(location: 4, length: 0)))
        XCTAssertNil(HighlightRangeSlice(range: NSRange(location: 4, length: 0),
                                         containsStart: true, containsEnd: true).clipped(to: NSRange(location: 3, length: 4)))
    }
}
