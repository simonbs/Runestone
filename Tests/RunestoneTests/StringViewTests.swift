@testable import Runestone
import XCTest

final class StringViewTests: XCTestCase {
    func testStringEquality() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        XCTAssertEqual(stringView.string, "Hello world")
    }

    func testPassingValidRangeToSubstring() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let range = NSRange(location: 6, length: 5)
        XCTAssertEqual(stringView.substring(in: range), "world")
    }

    func testPassingInvalidRangeToSubstring() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let range = NSRange(location: 8, length: 5)
        XCTAssertNil(stringView.substring(in: range))
    }

    func testPassingValidIndexToCharacterAt() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let character = stringView.substring(in: NSRange(location: 4, length: 1))
        XCTAssertEqual(character, "o")
    }

    func testPassingInvalidIndexToCharacterAt() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let character = stringView.substring(in: NSRange(location: 12, length: 1))
        XCTAssertNil(character)
    }

    func testGetCharacterFromEmojiString() {
        let str = "🥳🥳"
        let stringView = StringView(string: str)
        let character = stringView.substring(in: NSRange(location: 0, length: 2))
        XCTAssertEqual(character, "🥳")
    }

    func testGetBytesOfFirstCharacter() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 0, length: 2)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "H")
    }

    func testGetBytesOfTwoFirstCharacters() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 0, length: 4)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "He")
    }

    func testGetBytesOfSecondCharacter() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 2, length: 2)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "e")
    }

    func testGetBytesOfEntireString() {
        let str = "Hello world"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 0, length: str.byteCount)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "Hello world")
    }

    func testGetBytesOfEmoji() {
        let str = "🥳"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 0, length: 4)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "🥳")
    }

    func testGetBytesOfTwoEmojis() {
        let str = "🥳🥳"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 0, length: 8)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "🥳🥳")
    }

    func testGetBytesOfSecondEmoji() {
        let str = "🥳🥳"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 4, length: 4)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "🥳")
    }

    func testGetBytesOfComposedEmoji() {
        let str = "👨‍👩‍👧‍👦"
        let stringView = StringView(string: str)
        let byteRange = ByteRange(location: 0, length: 22)
        let bytes = stringView.bytes(in: byteRange)!
        XCTAssertEqual(string(from: bytes), "👨‍👩‍👧‍👦")
    }
}

private extension StringViewTests {
    private func string(from result: StringViewBytesResult) -> String {
        let data = Data(bytes: result.bytes, count: result.length.value)
        return String(data: data, encoding: String.preferredUTF16Encoding)!
    }
}
