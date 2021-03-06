@testable import Runestone
import XCTest

final class StringHelpersTests: XCTestCase {
    func testByteCountOfLetter() {
        let str = "H"
        XCTAssertEqual(str.byteCount, 2)
    }

    func testByteCountOfMultipleLetter() {
        let str = "Hello"
        XCTAssertEqual(str.byteCount, 10)
    }

    func testByteCountOfEmoji() {
        let str = "๐ฅณ"
        XCTAssertEqual(str.byteCount, 4)
    }

    func testByteCountOfMultipleEmojis() {
        let str = "๐ฅณ๐ฅณ"
        XCTAssertEqual(str.byteCount, 8)
    }

    func testByteCountOfComposedEmoji() {
        let str = "๐จโ๐ฉโ๐งโ๐ฆ"
        XCTAssertEqual(str.byteCount, 22)
    }
}
