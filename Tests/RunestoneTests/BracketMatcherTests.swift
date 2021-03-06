import XCTest
@testable import Runestone

final class BracketMatcherTests: XCTestCase {
    func testClosedIfStatement() {
        let string = "if (myVar) {}"
        let bracketMatcher = createBracketMatcher(for: string)
        let lineRange = 0 ... string.utf16.count
        // if (myVar) {|}
        XCTAssertTrue(bracketMatcher.hasMatchingBrackets(at: 12, in: lineRange))
        // if (myVar) {}|
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: 13, in: lineRange))
    }

    func testOpenIfStatement() {
        let string = "if (myVar) {"
        let bracketMatcher = createBracketMatcher(for: string)
        let lineRange = 0 ... string.utf16.count
        // if (myVar) {|}
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: 12, in: lineRange))
    }

    func testOutOfBounds() {
        let string = "if (myVar) {}"
        let bracketMatcher = createBracketMatcher(for: string)
        let lineRange = 0 ... string.utf16.count
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: -1, in: lineRange))
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: lineRange.lowerBound - 1, in: lineRange))
    }

    func testMultipleBrackets() {
        let string = "if (myVar) {} else {}"
        let bracketMatcher = createBracketMatcher(for: string)
        let lineRange = 0 ... string.utf16.count
        // if (myVar) {|} else {}
        XCTAssertTrue(bracketMatcher.hasMatchingBrackets(at: 12, in: lineRange))
        // if (myVar) {} else {|}
        XCTAssertTrue(bracketMatcher.hasMatchingBrackets(at: 20, in: lineRange))
        // if (myVar) {} el|se {}
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: 16, in: lineRange))
        // |if (myVar) {} else {}
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: lineRange.lowerBound, in: lineRange))
        // if (myVar) {} else {}|
        XCTAssertFalse(bracketMatcher.hasMatchingBrackets(at: lineRange.upperBound, in: lineRange))
    }
}

private extension BracketMatcherTests {
    private func createBracketMatcher(for string: String) -> BracketMatcher {
        let stringView = StringView(string: string)
        let characterPairs = [CurlyBracketCharacterPair()]
        return BracketMatcher(characterPairs: characterPairs, stringView: stringView)
    }
}

private struct CurlyBracketCharacterPair: EditorCharacterPair {
    let leading = "{"
    let trailing = "}"
    let insertAdditionalNewLine = true
}
