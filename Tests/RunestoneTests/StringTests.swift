import XCTest
@testable import Runestone

final class StringTests: XCTestCase {
    func testByteOffset() {
        let str1 = "Hello world"
        XCTAssertEqual(str1.byteOffset(at: 4), ByteCount(4))
        let str2 = "🥳🥳"
        XCTAssertEqual(str2.byteOffset(at: 2), ByteCount(4))
        XCTAssertEqual(str2.byteOffset(at: 4), ByteCount(8))
        let str3 = "Hello 🥳"
        XCTAssertEqual(str3.byteOffset(at: 2), ByteCount(2))
        XCTAssertEqual(str3.byteOffset(at: 8), ByteCount(10))
    }

    func testByteRangeFromNSRange() {
        let str1 = "Hello world"
        XCTAssertEqual(
            str1.byteRange(from: NSRange(location: 4, length: 2)),
            ByteRange(location: ByteCount(4), length: ByteCount(2)))
        let str2 = "🥳🥳"
        XCTAssertEqual(
            str2.byteRange(from: NSRange(location: 0, length: 2)),
            ByteRange(location: ByteCount(0), length: ByteCount(4)))
        XCTAssertEqual(
            str2.byteRange(from: NSRange(location: 2, length: 2)),
            ByteRange(location: ByteCount(4), length: ByteCount(4)))
    }

    func testLocation() {
        let str1 = "Hello world"
        XCTAssertEqual(str1.location(from: ByteCount(2)), 2)
        let str2 = "🥳🥳"
        XCTAssertEqual(str2.location(from: ByteCount(4)), 2)
        XCTAssertEqual(str2.location(from: ByteCount(8)), 4)
    }

    func testNSRangeFromByteRange() {
        let str1 = "Hello world"
        XCTAssertEqual(
            str1.range(from: ByteRange(location: ByteCount(0), length: ByteCount(2))),
            NSRange(location: 0, length: 2))
        let str2 = "🥳🥳"
        XCTAssertEqual(
            str2.range(from: ByteRange(location: ByteCount(0), length: ByteCount(4))),
            NSRange(location: 0, length: 2))
        XCTAssertEqual(
            str2.range(from: ByteRange(location: ByteCount(4), length: ByteCount(4))),
            NSRange(location: 2, length: 2))
    }
}
