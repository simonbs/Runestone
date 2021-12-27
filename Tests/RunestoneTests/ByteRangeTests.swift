@testable import Runestone
import XCTest

final class ByteRangeTests: XCTestCase {
    func testByteRangeFromNSRange() {
        let range1 = NSRange(location: 0, length: 2)
        let byteRange1 = ByteRange(utf16Range: range1)
        XCTAssertEqual(byteRange1.location, 0)
        XCTAssertEqual(byteRange1.length, 4)
        let range2 = NSRange(location: 2, length: 0)
        let byteRange2 = ByteRange(utf16Range: range2)
        XCTAssertEqual(byteRange2.location, 4)
        XCTAssertEqual(byteRange2.length, 0)
        let range3 = NSRange(location: 1, length: 8)
        let byteRange3 = ByteRange(utf16Range: range3)
        XCTAssertEqual(byteRange3.location, 2)
        XCTAssertEqual(byteRange3.length, 16)
    }
}
