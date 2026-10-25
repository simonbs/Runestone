@testable import Runestone
import UIKit
import XCTest

final class SpellCheckingServiceTests: XCTestCase {
    func testReportsDocumentUTF16RangesAndAppliesExclusions() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0)
        let text = "👨‍👩‍👧‍👦 café mispell marked active ignored mispell " as NSString
        let first = text.range(of: "mispell")
        let last = text.range(of: "mispell", options: .backwards)
        let completed = expectation(description: "Checked")
        service.schedule(text: text, visibleRange: NSRange(location: 0, length: text.length), language: "en_US",
                         excludedRanges: [text.range(of: "marked"), NSRange(location: NSMaxRange(text.range(of: "active")), length: 0)],
                         shouldCheck: { $0 != text.range(of: "ignored") }, completion: { ranges in
            XCTAssertEqual(ranges, [first, last])
            completed.fulfill()
        })
        wait(for: [completed], timeout: 2)
    }

    func testDebounceDiscardsSupersededDocument() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0.01)
        let obsolete = expectation(description: "Obsolete completion")
        obsolete.isInverted = true
        service.schedule(text: "mispell", visibleRange: NSRange(location: 0, length: 7), language: "en_US") { _ in
            obsolete.fulfill()
        }
        let completed = expectation(description: "Current completion")
        service.schedule(text: "correct", visibleRange: NSRange(location: 0, length: 7), language: "en_US") { ranges in
            XCTAssertTrue(ranges.isEmpty)
            completed.fulfill()
        }
        wait(for: [completed, obsolete], timeout: 0.1)
        XCTAssertEqual(checker.checkedStrings, ["correct"])
    }

    func testInvalidateCancelsPendingWork() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0.01)
        let obsolete = expectation(description: "Cancelled completion")
        obsolete.isInverted = true
        service.schedule(text: "mispell", visibleRange: NSRange(location: 0, length: 7), language: "en_US") { _ in
            obsolete.fulfill()
        }
        service.invalidate()
        wait(for: [obsolete], timeout: 0.05)
        XCTAssertTrue(checker.checkedStrings.isEmpty)
        XCTAssertTrue(service.misspelledRanges.isEmpty)
    }

    func testViewportSnapshotIsImmutableAndBounded() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0)
        let prefix = String(repeating: "correct ", count: 20_000)
        let text = NSMutableString(string: prefix + "mispell " + prefix)
        let range = NSRange(location: (prefix as NSString).length, length: 7)
        let completed = expectation(description: "Checked viewport")
        service.schedule(text: text, visibleRange: range, language: "en_US") { ranges in
            XCTAssertEqual(ranges, [range])
            completed.fulfill()
        }
        text.setString("changed")
        wait(for: [completed], timeout: 2)
        XCTAssertLessThanOrEqual(checker.checkedStrings.map { ($0 as NSString).length }.max() ?? 0, 2_048)
        XCTAssertLessThan(checker.checkedStrings.reduce(0) { $0 + ($1 as NSString).length }, 2_000)
        XCTAssertTrue(service.suggestions(for: range, in: text, language: "en_US").isEmpty)
    }

    func testChunksPreserveWordsAcrossBoundaryAndSkipOversizedIdentifiers() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0)
        let text = (String(repeating: "a ", count: 1_022) + "mispell " + String(repeating: "x", count: 4_000) + " mispell ") as NSString
        let completed = expectation(description: "Checked chunks")
        service.schedule(text: text, visibleRange: NSRange(location: 0, length: text.length), language: "en_US") { ranges in
            XCTAssertEqual(ranges, [text.range(of: "mispell"), text.range(of: "mispell", options: .backwards)])
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(checker.checkedStrings.allSatisfy { ($0 as NSString).length <= 2_048 })
        XCTAssertFalse(checker.checkedStrings.contains { $0.contains("xxx") })
    }

    func testDisjointViewportWindowsDoNotCopyHiddenColumnsOrStarveFollowingLines() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0)
        let hiddenColumns = String(repeating: "hidden ", count: 8_000)
        let text = ("mispell " + hiddenColumns + "\nmispell " + hiddenColumns) as NSString
        let first = text.range(of: "mispell")
        let last = text.range(of: "mispell", options: .backwards)
        let completed = expectation(description: "Checked both visible windows")
        service.schedule(text: text, visibleRanges: [first, last], language: "en_US") { ranges in
            XCTAssertEqual(ranges, [first, last])
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        // Each snapshot is observed once at offset zero, even when the checker finds multiple misspellings.
        XCTAssertLessThan(checker.snapshotLengths.reduce(0, +), 2_000)
        XCTAssertTrue(checker.snapshotLengths.allSatisfy { $0 <= 2_048 })
    }

    func testSnapshotBudgetIsSharedAcrossVisibleWindowsAndOverlapsAreMerged() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0)
        let firstLine = "mispell " + String(repeating: "correct ", count: 10_000)
        let text = (firstLine + "\nmispell " + String(repeating: "correct ", count: 10_000)) as NSString
        let second = text.range(of: "mispell", options: .backwards)
        let windows = [NSRange(location: 0, length: 30_000), NSRange(location: 100, length: 100), second]
        let completed = expectation(description: "Checked bounded windows")
        service.schedule(text: text, visibleRanges: windows, language: "en_US") { ranges in
            XCTAssertEqual(ranges, [NSRange(location: 0, length: 7), second])
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        XCTAssertLessThanOrEqual(checker.snapshotLengths.reduce(0, +), 16_384)
    }

    func testSuggestionsCheckSelectedWordImmediatelyAndRejectFragmentsAndUnsafeRanges() {
        let checker = StubSpellChecker()
        let service = SpellCheckingService(checker: checker, debounceInterval: 0)
        let range = NSRange(location: 0, length: 7)
        XCTAssertEqual(service.suggestions(for: range, in: "mispell", language: "en_US"), ["misspell"])
        XCTAssertTrue(service.suggestions(for: range, in: "correct", language: "en_US").isEmpty)
        XCTAssertTrue(service.suggestions(for: NSRange(location: NSNotFound, length: 1), in: "mispell", language: "en_US").isEmpty)
        XCTAssertTrue(service.suggestions(for: NSRange(location: 0, length: Int.max), in: "mispell", language: "en_US").isEmpty)
        XCTAssertTrue(service.suggestions(for: range, in: "mispelling", language: "en_US").isEmpty)
        XCTAssertTrue(service.suggestions(for: NSRange(location: 1, length: 7), in: "xmispell", language: "en_US").isEmpty)
    }

    func testFilterCanInvalidateWithoutPublishingStaleRanges() {
        let service = SpellCheckingService(checker: StubSpellChecker(), debounceInterval: 0)
        let obsolete = expectation(description: "Invalidated completion")
        obsolete.isInverted = true
        service.schedule(text: "mispell", visibleRange: NSRange(location: 0, length: 7), language: "en_US", shouldCheck: { _ in
            service.invalidate()
            return true
        }, completion: { _ in obsolete.fulfill() })
        wait(for: [obsolete], timeout: 0.05)
        XCTAssertTrue(service.misspelledRanges.isEmpty)
    }

    func testSystemCheckerFindsMisspellingAndOffersCorrection() throws {
        guard UITextChecker.availableLanguages.contains("en_US") else {
            throw XCTSkip("The simulator does not have the English spelling dictionary installed.")
        }
        let service = SpellCheckingService(debounceInterval: 0)
        let text = "This is a mispelled word." as NSString
        let misspelling = text.range(of: "mispelled")
        let completed = expectation(description: "System dictionary checked")
        service.schedule(text: text, visibleRange: NSRange(location: 0, length: text.length), language: "en_US") { ranges in
            XCTAssertTrue(ranges.contains(misspelling))
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
        XCTAssertTrue(service.suggestions(for: misspelling, in: text, language: "en_US").contains("misspelled"))
    }
}

private final class StubSpellChecker: SpellChecking {
    var checkedStrings: [String] = []
    var snapshotLengths: [Int] = []

    func rangeOfMisspelledWord(in string: String, range: NSRange, startingAt offset: Int, wrap: Bool, language: String) -> NSRange {
        checkedStrings.append(string)
        if offset == 0 {
            snapshotLengths.append((string as NSString).length)
        }
        let text = string as NSString
        let searchRange = NSRange(location: offset, length: text.length - offset)
        return ["mispell", "marked", "active", "ignored"].map { text.range(of: $0, range: searchRange) }
            .filter { $0.location != NSNotFound }.min { $0.location < $1.location } ?? NSRange(location: NSNotFound, length: 0)
    }

    func guesses(forWordRange range: NSRange, in string: String, language: String) -> [String]? {
        ["misspell"]
    }
}
