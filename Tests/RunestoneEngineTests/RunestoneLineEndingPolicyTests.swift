import Foundation
@testable import RunestoneEngine
import XCTest

final class RunestoneLineEndingPolicyTests: XCTestCase {
    func testUniformStylesAtStartInsideLineAndEnd() {
        for ending in ["\n", "\r\n", "\r", "\u{0085}", "\u{2028}", "\u{2029}"] {
            let text = "first\(ending)second\(ending)third" as NSString
            for location in [0, 2, 5 + ending.utf16.count, text.length] {
                XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: text, replacing: NSRange(location: location, length: 0)),
                               ending, "ending \(ending.debugDescription), location \(location)")
            }
        }
    }

    func testUnambiguousLocalDelimiterWinsOverDifferentDocumentMajority() {
        let text = "one\r\ntwo\r\nthree\nfour\nfive\n" as NSString
        let location = text.range(of: "two").location + 1
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: text, replacing: NSRange(location: location, length: 0)), "\r\n")
        // At a document edge, the only neighboring delimiter is sufficient.
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: text, replacing: NSRange(location: 0, length: 0)), "\r\n")
    }

    func testConflictingNeighborsUseUniquePredominantStyleOrLFFallbackOnTie() {
        let predominant = "a\r\nb\nc\r\n" as NSString
        let middle = predominant.range(of: "b").location
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: predominant, replacing: NSRange(location: middle, length: 0)), "\r\n")
        let tie = "a\rb\nc" as NSString
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: tie, replacing: NSRange(location: 2, length: 0)), "\n")
        let unicodeMajority = "a\u{2028}b\rc\u{2028}d" as NSString
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: unicodeMajority, replacing: NSRange(location: 2, length: 0)), "\u{2028}")
    }

    func testSelectionIgnoresRemovedDelimitersForLocalContext() {
        let text = "a\r\nb\nc\r\nd" as NSString
        let selection = text.range(of: "b\nc")
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: text, replacing: selection), "\r\n")
        XCTAssertEqual(text as String, "a\r\nb\nc\r\nd")
    }

    func testReplacingWholeDocumentUsesOriginalPredominance() {
        let text = "a\r\nb\r\nc\n" as NSString
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: text, replacing: NSRange(location: 0, length: text.length)), "\r\n")
        let tie = "a\rb\u{2029}" as NSString
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: tie, replacing: NSRange(location: 0, length: tie.length)), "\n")
    }

    func testEmptyAndUnterminatedDocumentsDefaultToLF() {
        for text in ["", "without delimiters", "👩🏽‍💻"] {
            let snapshot = text as NSString
            XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: snapshot, replacing: NSRange(location: snapshot.length, length: 0)), "\n")
        }
    }

    func testRejectsInvalidUTF16RangesAndSplitCRLF() {
        let text = "A😀\r\nB" as NSString
        let invalid = [
            NSRange(location: NSNotFound, length: 0),
            NSRange(location: 0, length: Int.max),
            NSRange(location: text.length + 1, length: 0),
            NSRange(location: 2, length: 0), // between the surrogate pair
            NSRange(location: 1, length: 1),
            NSRange(location: 4, length: 0), // between CR and LF
            NSRange(location: 3, length: 1),
            NSRange(location: 4, length: 1)
        ]
        for range in invalid {
            XCTAssertNil(RunestoneLineEndingPolicy.newline(in: text, replacing: range), "range: \(range)")
        }
        XCTAssertEqual(RunestoneLineEndingPolicy.newline(in: text, replacing: NSRange(location: 1, length: 2)), "\r\n")
    }
}
