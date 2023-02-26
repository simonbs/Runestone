import Foundation
@testable import Runestone
import XCTest

final class NSRangeTests: XCTestCase {
    func testNSRangeFromByteRange() {
        let byteRange1 = ByteRange(location: 0, length: 4)
        let range1 = NSRange(byteRange1)
        XCTAssertEqual(range1.location, 0)
        XCTAssertEqual(range1.length, 2)
        let byteRange2 = ByteRange(location: 4, length: 0)
        let range2 = NSRange(byteRange2)
        XCTAssertEqual(range2.location, 2)
        XCTAssertEqual(range2.length, 0)
        let byteRange3 = ByteRange(location: 2, length: 16)
        let range3 = NSRange(byteRange3)
        XCTAssertEqual(range3.location, 1)
        XCTAssertEqual(range3.length, 8)
    }

    func testNSRangeFitsInCppingRange() {
        let range = NSRange(location: 10, length: 4)
        let cappingRange = NSRange(location: 2, length: 20)
        let cappedRange = range.capped(to: cappingRange)
        XCTAssertEqual(cappedRange.lowerBound, 10)
        XCTAssertEqual(cappedRange.upperBound, 14)
    }

    func testNSRangeLowerBoundExceedsCappingRange() {
        let range = NSRange(location: 10, length: 4)
        let cappingRange = NSRange(location: 12, length: 8)
        let cappedRange = range.capped(to: cappingRange)
        XCTAssertEqual(cappedRange.lowerBound, 12)
        XCTAssertEqual(cappedRange.upperBound, 14)
    }

    func testNSRangeUpperBoundExceedsCappingRange() {
        let range = NSRange(location: 14, length: 10)
        let cappingRange = NSRange(location: 12, length: 8)
        let cappedRange = range.capped(to: cappingRange)
        XCTAssertEqual(cappedRange.lowerBound, 14)
        XCTAssertEqual(cappedRange.upperBound, 20)
    }

    func testNSRangeLowerBoundAndUpperBoundExceedsCappingRange() {
        let range = NSRange(location: 10, length: 20)
        let cappingRange = NSRange(location: 12, length: 8)
        let cappedRange = range.capped(to: cappingRange)
        XCTAssertEqual(cappedRange.lowerBound, 12)
        XCTAssertEqual(cappedRange.upperBound, 20)
    }

    func testNSRangCappedToRangeWithLocationZeroAndLengthZero() {
        let range = NSRange(location: 10, length: 20)
        let cappingRange = NSRange(location: 0, length: 0)
        let cappedRange = range.capped(to: cappingRange)
        XCTAssertEqual(cappedRange.lowerBound, 0)
        XCTAssertEqual(cappedRange.upperBound, 0)
    }

    func testNSRangCappedToRangeWithLengthZero() {
        let range = NSRange(location: 10, length: 20)
        let cappingRange = NSRange(location: 5, length: 0)
        let cappedRange = range.capped(to: cappingRange)
        XCTAssertEqual(cappedRange.lowerBound, 5)
        XCTAssertEqual(cappedRange.length, 0)
    }

    func testLocalRangeFromRangeContainedInParent() {
        let range = NSRange(location: 52, length: 4)
        let parentRange = NSRange(location: 50, length: 60)
        let localRange = range.local(to: parentRange)
        XCTAssertEqual(localRange.lowerBound, 2)
        XCTAssertEqual(localRange.upperBound, 6)
    }

    func testLocalRangeFromRangeWithLowerBoundsExceedingParent() {
        let range = NSRange(location: 45, length: 10)
        let parentRange = NSRange(location: 50, length: 60)
        let localRange = range.local(to: parentRange)
        XCTAssertEqual(localRange.lowerBound, -5)
        XCTAssertEqual(localRange.upperBound, 5)
    }

    func testLocalRangeFromRangeWithUpperBoundsExceedingParent() {
        let range = NSRange(location: 55, length: 10)
        let parentRange = NSRange(location: 50, length: 60)
        let localRange = range.local(to: parentRange)
        XCTAssertEqual(localRange.lowerBound, 5)
        XCTAssertEqual(localRange.upperBound, 15)
    }

    func testLocalRangeFromRangeOutsideParent() {
        let range = NSRange(location: 10, length: 4)
        let parentRange = NSRange(location: 50, length: 60)
        let localRange = range.local(to: parentRange)
        XCTAssertEqual(localRange.lowerBound, -40)
        XCTAssertEqual(localRange.upperBound, -36)
    }
}
