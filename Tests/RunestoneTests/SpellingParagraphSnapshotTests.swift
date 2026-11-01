import Foundation
@testable import Runestone
import XCTest

final class SpellingParagraphSnapshotTests: XCTestCase {
    func testParagraphBoundariesUseDocumentUTF16OffsetsAndSkipEmptyCRLFParagraphs() {
        let first = "👋 This paragraph has enough English prose to explain spelling in the document editor."
        let second = "Dette afsnit indeholder dansk tekst som bliver kontrolleret med sin egen passende ordbog."
        let text = (first + "\r\n\r\n" + second) as NSString
        let snapshots = ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [NSRange(location: 0, length: text.length)])

        XCTAssertEqual(snapshots.map { $0.text }, [first, second])
        XCTAssertEqual(snapshots.map { $0.range }, [text.range(of: first), text.range(of: second)])
    }

    func testOverlappingViewportWindowsDoNotDuplicateParagraphs() {
        let text = "This paragraph contains several visible words from the same line in the document editor." as NSString
        let snapshots = ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [text.range(of: "visible"), text.range(of: "document")])

        XCTAssertEqual(snapshots.map { $0.text }, [text as String])
        XCTAssertEqual(snapshots.map { $0.range }, [NSRange(location: 0, length: text.length)])
    }

    func testHorizontallyScrolledLongLineSamplesNearVisibleColumnsAndBoundsTheCopiedText() {
        let hidden = String(repeating: "hidden ", count: 100_000)
        let visible = "This visible paragraph explains the editor and its spelling dictionaries for the current reader."
        let text = (hidden + visible + hidden) as NSString
        let visibleRange = text.range(of: visible)
        let snapshots = ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [visibleRange])

        XCTAssertFalse(snapshots.isEmpty)
        XCTAssertTrue(snapshots.contains { $0.text.contains(visible) })
        XCTAssertTrue(snapshots.allSatisfy { $0.range.length <= 2_048 })
        XCTAssertLessThanOrEqual(snapshots.reduce(0) { $0 + $1.range.length }, 16_384)
        XCTAssertTrue(snapshots.allSatisfy { $0.range.location > 0 }, "A distant viewport must not copy from the beginning of a huge line.")
    }

    func testParagraphAndSnapshotBudgetsBoundWorkForAnExtremelyLargeViewport() {
        let paragraph = "This paragraph explains how the editor selects a dictionary for checking the visible words.\n"
        let text = String(repeating: paragraph, count: 10_000) as NSString
        let snapshots = ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [NSRange(location: 0, length: text.length)])

        XCTAssertFalse(snapshots.isEmpty)
        XCTAssertLessThanOrEqual(snapshots.count, 16)
        XCTAssertLessThanOrEqual(snapshots.reduce(0) { $0 + $1.range.length }, 16_384)
        XCTAssertTrue(snapshots.allSatisfy { $0.range.length <= 2_048 })
    }

    func testBlankLineViewportAndRepeatedWindowsHaveBoundedCharacterScanning() {
        let text = CountingParagraphString(content: String(repeating: "\n", count: 1_000_000))
        let fullRange = NSRange(location: 0, length: text.length)
        XCTAssertTrue(ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [fullRange]).isEmpty)
        XCTAssertLessThan(text.characterReads, 150_000, "Empty paragraphs must still consume a finite scanning budget.")

        let repeated = CountingParagraphString(content: "\n")
        let ranges = Array(repeating: NSRange(location: 0, length: 1), count: 1_000_000)
        XCTAssertTrue(ParagraphSpellingLanguageService.snapshots(text: repeated, visibleRanges: ranges).isEmpty)
        XCTAssertLessThan(repeated.characterReads, 1_000, "Duplicate viewport windows must not create unbounded boundary scans.")
    }

    func testClippedSamplesNeverSplitSurrogatesCombiningMarksOrJoinedEmoji() {
        let prefix = String(repeating: "a ", count: 511)
        let clusters = ["👨‍👩‍👧‍👦", "e\u{301}", "🇩🇰", "\u{0600} \u{301}"]
        for cluster in clusters {
            let text = (prefix + cluster + String(repeating: " visible words", count: 300)) as NSString
            let snapshots = ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [NSRange(location: 2_048, length: 20)])
            XCTAssertFalse(snapshots.isEmpty)
            for snapshot in snapshots {
                XCTAssertEqual(text.rangeOfComposedCharacterSequences(for: snapshot.range), snapshot.range)
                XCTAssertFalse(snapshot.text.contains("�"))
            }
        }
    }

    func testSnapshotsOwnImmutableTextAndRejectInvalidViewportRanges() {
        let text = NSMutableString(string: "This paragraph is captured before the document changes while recognition is still pending.")
        let original = text as String
        let snapshots = ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: [NSRange(location: 0, length: text.length)])
        text.setString("The document was replaced.")
        XCTAssertEqual(snapshots.map { $0.text }, [original])

        let invalidRanges = [NSRange(location: NSNotFound, length: 1), NSRange(location: -1, length: 1),
                             NSRange(location: 0, length: Int.max), NSRange(location: 0, length: 0)]
        XCTAssertTrue(ParagraphSpellingLanguageService.snapshots(text: text, visibleRanges: invalidRanges).isEmpty)
    }
}

private final class CountingParagraphString: NSString {
    private var content: NSString = ""
    private(set) var characterReads = 0

    convenience init(content: String) {
        self.init()
        self.content = content as NSString
    }

    override var length: Int {
        content.length
    }

    override func character(at index: Int) -> unichar {
        characterReads += 1
        return content.character(at: index)
    }

    override func substring(with range: NSRange) -> String {
        content.substring(with: range)
    }
}
