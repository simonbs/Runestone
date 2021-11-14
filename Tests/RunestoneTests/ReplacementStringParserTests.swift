import XCTest
@testable import Runestone

final class ReplacementStringParserTests: XCTestCase {
    func testNoPlaceholders() {
        let parser = ReplacementStringParser(string: "hello world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello world")]))
    }

    func testSinglePlaceholderOnly() {
        let parser = ReplacementStringParser(string: "$1")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(1)]))
    }

    func testTwoPlaceholdersOnly() {
        let parser = ReplacementStringParser(string: "$1$2")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(1), .placeholder(2)]))
    }

    func testTwoOfSamePlaceholdersOnly() {
        let parser = ReplacementStringParser(string: "$1$1")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(1), .placeholder(1)]))
    }

    func testPlaceholderWithTwoDigits() {
        let parser = ReplacementStringParser(string: "$12")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(12)]))
    }

    func testPlaceholderWithThreeDigits() {
        let parser = ReplacementStringParser(string: "$123")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(123)]))
    }

    func testPlaceholderAtEndOString() {
        let parser = ReplacementStringParser(string: "hello world $1")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello world "), .placeholder(1)]))
    }

    func testPlaceholderAtBeginningOfString() {
        let parser = ReplacementStringParser(string: "$1 hello world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(1), .text(" hello world")]))
    }

    func testPlaceholderInMiddleOfString() {
        let parser = ReplacementStringParser(string: "hello $1 world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello "), .placeholder(1), .text(" world")]))
    }

    func testPlaceholderInMiddleOfStringWithoutSpaces() {
        let parser = ReplacementStringParser(string: "hello$1world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello"), .placeholder(1), .text("world")]))
    }

    func testEscapedPlaceholder() {
        let parser = ReplacementStringParser(string: "\\$1")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("$1")]))
    }

    func testTwoEscapedPlaceholders() {
        let parser = ReplacementStringParser(string: "\\$1\\$2")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("$1$2")]))
    }

    func testEscapedPlaceholderWithMultipleDigits() {
        let parser = ReplacementStringParser(string: "\\$1234")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("$1234")]))
    }

    func testEscapedInMiddleOfString() {
        let parser = ReplacementStringParser(string: "hello\\$1world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello$1world")]))
    }

    func testEscapedPlaceholderAndPlaceholder() {
        let parser = ReplacementStringParser(string: "hello \\$1 world $2")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello $1 world "), .placeholder(2)]))
    }

    func testEscapedPlaceholderFollowedByPlaceholder() {
        let parser = ReplacementStringParser(string: "\\$1$2")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("$1"), .placeholder(2)]))
    }
}
