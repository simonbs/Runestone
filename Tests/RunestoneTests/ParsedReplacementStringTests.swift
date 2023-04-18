// swiftlint:disable force_try
@testable import Runestone
import XCTest

final class ParsedReplacementStringTests: XCTestCase {
    func testSinglePlaceholder() {
        let string = "hello world"
        let regex = try! NSRegularExpression(pattern: "hello (world)", options: [])
        let range = NSRange(location: 0, length: string.utf16.count)
        let textCheckingResults = regex.matches(in: string, options: [], range: range)
        let textCheckingResult = textCheckingResults[0]
        let parsedReplacementString = ParsedReplacementString(components: [.text("howdy "), .placeholder(1), .text(" and friends")])
        let expandedString = parsedReplacementString.string(byMatching: textCheckingResult, in: string as NSString)
        XCTAssertEqual(expandedString, "howdy world and friends")
    }

    func testPlacehodlerAtIndex0() {
        let string = "hello world"
        let regex = try! NSRegularExpression(pattern: "hello world", options: [])
        let range = NSRange(location: 0, length: string.utf16.count)
        let textCheckingResults = regex.matches(in: string, options: [], range: range)
        let textCheckingResult = textCheckingResults[0]
        let parsedReplacementString = ParsedReplacementString(components: [.text("hello "), .placeholder(0), .text(" world")])
        let expandedString = parsedReplacementString.string(byMatching: textCheckingResult, in: string as NSString)
        XCTAssertEqual(expandedString, "hello hello world world")
    }

    func testPlaceholderThatIsOutOfBounds() {
        let string = "hello world"
        let regex = try! NSRegularExpression(pattern: "hello (world)", options: [])
        let range = NSRange(location: 0, length: string.utf16.count)
        let textCheckingResults = regex.matches(in: string, options: [], range: range)
        let textCheckingResult = textCheckingResults[0]
        let parsedReplacementString = ParsedReplacementString(components: [.text("hello "), .placeholder(1), .text(" world "), .placeholder(2)])
        let expandedString = parsedReplacementString.string(byMatching: textCheckingResult, in: string as NSString)
        XCTAssertEqual(expandedString, "hello world world $2")
    }
}
// swiftlint:enable force_try
