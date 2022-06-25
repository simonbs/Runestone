@testable import Runestone
import XCTest

final class SearchQueryTests: XCTestCase {
    private let sampleText: NSString = """
/**
 * This is a Runestone text view with syntax highlighting
 * for the JavaScript programming language.
 */

let names = ["Steve Jobs", "Tim Cook", "Eddy Cue"]
let years = [1955, 1960, 1964]
printNamesAndYears(names, years)

// Print the year each person was born.
function printNamesAndYears(names, years) {
  for (let i = 0; i < names.length; i++) {
    console.log(names[i] + " was born in " + years[i])
  }
}
"""

    func testContainsMatchMethod() {
        let searchQuery = SearchQuery(text: "names", matchMethod: .contains)
        let ranges = searchQuery.matches(in: sampleText)
        XCTAssertEqual(ranges.count, 7)
    }

    func testFullWordMatchMethod() {
        let searchQuery = SearchQuery(text: "names", matchMethod: .fullWord)
        let ranges = searchQuery.matches(in: sampleText)
        XCTAssertEqual(ranges.count, 5)
    }

    func testStartsWithMatchMethod() {
        let searchQuery = SearchQuery(text: "nam", matchMethod: .startsWith)
        let ranges = searchQuery.matches(in: sampleText)
        XCTAssertEqual(ranges.count, 5)
    }

    func testEndsWithMatchMethod() {
        let searchQuery = SearchQuery(text: "rs", matchMethod: .endsWith)
        let ranges = searchQuery.matches(in: sampleText)
        XCTAssertEqual(ranges.count, 6)
    }

    func testRegularExpressionMatchMethod() {
        // Matches strings containing the names.
        let searchQuery = SearchQuery(text: "\"[A-Z][a-z]+ [A-Z][a-z]+\"", matchMethod: .regularExpression)
        let ranges = searchQuery.matches(in: sampleText)
        XCTAssertEqual(ranges.count, 3)
    }
}
