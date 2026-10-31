import Foundation
import RunestoneEngine
import XCTest

final class StringViewStorageTests: XCTestCase {
    func testUTF16BytesFollowMutationsAndRejectOutOfBoundsRanges() throws {
        let text = StringView(string: "A😀\r\nZ")
        let emojiRange = ByteRange(utf16Range: NSRange(location: 1, length: 2))
        let initial = try XCTUnwrap(text.bytes(in: emojiRange))
        defer { initial.bytes.deallocate() }
        XCTAssertEqual(initial.length.value, 4)
        let emojiData = Data(bytes: initial.bytes, count: initial.length.value)
        XCTAssertEqual(String(data: emojiData, encoding: nativeUTF16), "😀")
        XCTAssertNil(text.bytes(in: ByteRange(location: 0, length: 100)))

        text.replaceText(in: NSRange(location: 1, length: 2), with: "é")
        XCTAssertEqual(text.string as String, "Aé\r\nZ")
        let changed = try XCTUnwrap(text.bytes(in: ByteRange(utf16Range: NSRange(location: 1, length: 1))))
        defer { changed.bytes.deallocate() }
        XCTAssertEqual(String(data: Data(bytes: changed.bytes, count: changed.length.value), encoding: nativeUTF16), "é")
        XCTAssertEqual(String(data: Data(bytes: initial.bytes, count: initial.length.value), encoding: nativeUTF16), "😀")

        text.string = "other"
        XCTAssertEqual(text.substring(in: NSRange(location: 0, length: 5)), "other")
        XCTAssertNil(text.substring(in: NSRange(location: 4, length: 2)))
    }

    private var nativeUTF16: String.Encoding {
        let little = "abc".data(using: .utf16LittleEndian)
        let native = "abc".data(using: .utf16)?.suffix(from: 2)
        return little == native ? .utf16LittleEndian : .utf16BigEndian
    }
}
