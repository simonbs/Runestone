import XCTest
@testable import Runestone

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
}
