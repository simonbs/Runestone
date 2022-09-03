@testable import Runestone
import XCTest

final class LineEndingDetectorTests: XCTestCase {
    func testEmptyString() {
        let string = ""
        let lineEndings = detectLineEndings(in: string)
        XCTAssertNil(lineEndings)
    }

    func testNoLineBreakString() {
        let string = "Hello World!"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, nil)
    }

    func testLineFeedOnlyString() {
        let string = "\n"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .lf)
    }

    func testCarriageReturnOnlyString() {
        let string = "\r"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .cr)
    }

    func testCarriageReturnLineFeedOnlyString() {
        let string = "\r\n"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .crlf)
    }

    func testStringWithMultipleLineFeed() {
        let string = "Hello\nworld\nhow\nare\nyou\ndoing"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .lf)
    }

    func testStringWithMultipleCarriageReturn() {
        let string = "Hello\rworld\rhow\rare\ryou\rdoing"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .cr)
    }

    func testStringWithMultipleCarriageLineFeedReturn() {
        let string = "Hello\r\nworld\r\nhow\r\nare\r\nyou\r\ndoing"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .crlf)
    }

    func testStringWithEqualNumberOfDifferentLineEndingsStartingWithLineFeed() {
        // When there's an equal amount of line breaks we fallback to the order of LineEnding.allCases.
        let string = "Hello\nworld\rhello\nworld\r"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .lf)
    }

    func testStringWithEqualNumberOfDifferentLineEndingsStartignWithCarriageReturn() {
        // When there's an equal amount of line breaks we fallback to the order of LineEnding.allCases.
        let string = "Hello\rworld\nhello\rworld\n"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .lf)
    }

    func testStringWithDominantLineFeed() {
        let string = "Hello\nworld\nhello\rworld\n"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .lf)
    }

    func testStringWithDominantCarriageReturn() {
        let string = "Hello\rworld\rhello\nworld\r"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .cr)
    }

    func testStringWithDominantCarriageReturnLineFeed() {
        let string = "Hello\r\nworld\r\nhello\rworld\r\n"
        let lineEndings = detectLineEndings(in: string)
        XCTAssertEqual(lineEndings, .crlf)
    }
}

private extension LineEndingDetectorTests {
    private func detectLineEndings(in string: String) -> LineEnding? {
        let stringView = StringView(string: string)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let detector = LineEndingDetector(lineManager: lineManager, stringView: stringView)
        return detector.detect()
    }
}
