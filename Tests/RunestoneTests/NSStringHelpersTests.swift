@testable import Runestone
import XCTest

final class NSStringHelpersTests: XCTestCase {
    func testByteCountOfLetter() {
        let str = "H" as NSString
        XCTAssertEqual(str.byteCount, 2)
    }

    func testByteCountOfMultipleLetter() {
        let str = "Hello" as NSString
        XCTAssertEqual(str.byteCount, 10)
    }

    func testByteCountOfEmoji() {
        let str = "🥳" as NSString
        XCTAssertEqual(str.byteCount, 4)
    }

    func testByteCountOfMultipleEmojis() {
        let str = "🥳🥳" as NSString
        XCTAssertEqual(str.byteCount, 8)
    }

    func testByteCountOfComposedEmoji() {
        let str = "👨‍👩‍👧‍👦" as NSString
        XCTAssertEqual(str.byteCount, 22)
    }
}
