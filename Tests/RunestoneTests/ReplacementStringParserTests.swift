@testable import Runestone
import XCTest

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

    func testPlaceholderAtEndOfString() {
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

    func testDollarSignFollowedByLetter() {
        let parser = ReplacementStringParser(string: "hello $world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello $world")]))
    }

    func testStringEndingWithDollarSign() {
        let parser = ReplacementStringParser(string: "hello world $")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello world $")]))
    }

    func testStringBeginnignWithDolarSign() {
        let parser = ReplacementStringParser(string: "$ hello world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("$ hello world")]))
    }

    func testStringContainingOnlyDollarSign() {
        let parser = ReplacementStringParser(string: "$")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("$")]))
    }

    func testStringEndingWithBackslash() {
        let parser = ReplacementStringParser(string: "hello world \\")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello world \\")]))
    }

    func testEmptyString() {
        let parser = ReplacementStringParser(string: "")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: []))
    }

    func testStringContainingTwoBackslashes() {
        let parser = ReplacementStringParser(string: "hello \\\\ world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \\ world")]))
    }

    func testEscapedModifier() {
        let parser = ReplacementStringParser(string: "hello \\\\u world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \\u world")]))
    }

    func testModifierWithNoMeaning() {
        let parser = ReplacementStringParser(string: "\\uhello")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("\\uhello")]))
    }

    func testSingleModifier() {
        let parser = ReplacementStringParser(string: "hello \\u$1 world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [
            .text("hello "),
            .placeholder(modifiers: [.uppercaseLetter], index: 1),
            .text(" world")
        ]))
    }

    func testMultipleModifiers() {
        let parser = ReplacementStringParser(string: "hello \\u$1 \\L$2 world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [
            .text("hello "),
            .placeholder(modifiers: [.uppercaseLetter], index: 1),
            .text(" "),
            .placeholder(modifiers: [.lowercaseAllLetters], index: 2),
            .text(" world")
        ]))
    }

    func testMultipleModifiersOnSinglePlaceholder() {
        let parser = ReplacementStringParser(string: "hello \\u\\l\\U$1 world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [
            .text("hello "),
            .placeholder(modifiers: [.uppercaseLetter, .lowercaseLetter, .uppercaseAllLetters], index: 1),
            .text(" world")
        ]))
    }

    func testOnlyPlaceholderWithSingleModifier() {
        let parser = ReplacementStringParser(string: "\\u$1")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.placeholder(modifiers: [.uppercaseLetter], index: 1)]))
    }

    func testOnlyPlaceholderWithMultipleModifiers() {
        let parser = ReplacementStringParser(string: "\\u\\l\\U$1")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [
            .placeholder(modifiers: [.uppercaseLetter, .lowercaseLetter, .uppercaseAllLetters], index: 1)
        ]))
    }

    func testMultipleModifiersWithNoMeaning() {
        let parser = ReplacementStringParser(string: "\\u\\l\\UHello")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("\\u\\l\\UHello")]))
    }

    func testModifierInFrontOfEscapedDollarSign() {
        let parser = ReplacementStringParser(string: "\\u\\$")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("\\u$")]))
    }

    func testModifiersFollowedByInvalidModifier() {
        let parser = ReplacementStringParser(string: "\\u\\l\\A")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("\\u\\l\\A")]))
    }

    func testStringContainingLineFeed() {
        let parser = ReplacementStringParser(string: "hello \\n world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \n world")]))
    }

    func testStringContainingCarriageReturn() {
        let parser = ReplacementStringParser(string: "hello \\r world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \r world")]))
    }

    func testStringContainingCarriageReturnLineFeed() {
        let parser = ReplacementStringParser(string: "hello \\r\\n world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \r\n world")]))
    }

    func testStringContainingTab() {
        let parser = ReplacementStringParser(string: "hello \\t world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \t world")]))
    }

    func testStringContainingEscapedLineFeed() {
        let parser = ReplacementStringParser(string: "hello \\\\n world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \\n world")]))
    }

    func testStringContainingEscapedCarriageReturn() {
        let parser = ReplacementStringParser(string: "hello \\\\r world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \\r world")]))
    }

    func testStringContainingEscapedCarriageReturnLineFeed() {
        let parser = ReplacementStringParser(string: "hello \\\\r\\\\n world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \\r\\n world")]))
    }

    func testStringContainingEscapedTab() {
        let parser = ReplacementStringParser(string: "hello \\\\t world")
        let parsedReplacementString = parser.parse()
        XCTAssertEqual(parsedReplacementString, .init(components: [.text("hello \\t world")]))
    }
}
