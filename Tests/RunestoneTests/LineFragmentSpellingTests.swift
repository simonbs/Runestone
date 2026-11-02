import CoreText
@testable import Runestone
import UIKit
import XCTest

final class LineFragmentSpellingTests: XCTestCase {
    func testHorizontalViewportSkipsHiddenPrefixOfLongLine() throws {
        let prefix = String(repeating: "word ", count: 4_000)
        let string = prefix + "mispelled " + prefix
        let wordRange = (string as NSString).range(of: "mispelled")
        let renderer = renderer(string: string, range: NSRange(location: 0, length: (string as NSString).length))
        let wordStart = width(of: prefix)
        let wordEnd = wordStart + width(of: "mispelled")

        let ranges = renderer.visibleCharacterRanges(in: (wordStart - 8) ... (wordEnd + 8))
        let range = try XCTUnwrap(ranges.first)

        XCTAssertEqual(ranges.count, 1)
        XCTAssertLessThan(range.length, 30)
        XCTAssertGreaterThan(range.location, 19_990)
        XCTAssertEqual(NSIntersectionRange(range, wordRange), wordRange)
    }

    func testSpellingRangeSplitsAcrossWrappedFragmentsAfterEmoji() throws {
        let string = "😀 mispelled"
        let wordRange = (string as NSString).range(of: "mispelled")
        let first = renderer(string: string, range: NSRange(location: 0, length: 7))
        let second = renderer(string: string, range: NSRange(location: 7, length: 5))

        let firstSegment = try XCTUnwrap(first.spellingUnderlineSegments(in: wordRange).first)
        let secondSegment = try XCTUnwrap(second.spellingUnderlineSegments(in: wordRange).first)

        XCTAssertEqual(firstSegment.lowerBound, width(of: "😀 "), accuracy: 0.5)
        XCTAssertEqual(firstSegment.upperBound - firstSegment.lowerBound, width(of: "misp"), accuracy: 0.5)
        XCTAssertEqual(secondSegment.lowerBound, 0, accuracy: 0.5)
        XCTAssertEqual(secondSegment.upperBound, width(of: "elled"), accuracy: 0.5)
        XCTAssertTrue(second.spellingUnderlineSegments(in: NSRange(location: 0, length: 2)).isEmpty)
    }

    func testRightToLeftWordDoesNotUnderlineAdjacentLeftToRightText() throws {
        let string = "ABC אבגד DEF"
        let wordRange = (string as NSString).range(of: "אבגד")
        let renderer = renderer(string: string, range: NSRange(location: 0, length: (string as NSString).length))

        let segments = renderer.spellingUnderlineSegments(in: wordRange)
        let segment = try XCTUnwrap(segments.first)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segment.lowerBound, width(of: "ABC "), accuracy: 0.5)
        XCTAssertEqual(segment.upperBound - segment.lowerBound, width(of: "אבגד"), accuracy: 0.5)
    }

    @MainActor
    func testVisibleSpellingRangesFollowCompletedLayoutAcrossEditsScrollReflowAndFolding() {
        let text = String(repeating: "office אבגד 😀 words ", count: 40) + "\nsecond visible paragraph"
        let fixture = SpellingLayoutFixture(text: text)
        fixture.layoutNow()
        // Do not read the ranges before editing. The eventual request still
        // belongs to the completed layout, including its old document offsets.
        let beforeEdit = fixture.eagerRanges()
        XCTAssertFalse(beforeEdit.isEmpty)
        let edit = TextEditHelper(stringView: fixture.stringView, lineManager: fixture.lineManager, lineEndings: .lf)
            .replaceText(in: NSRange(location: 0, length: 0), with: "inserted paragraph\n")
        fixture.layout.redisplayLines(withIDs: Set(edit.lineChangeSet.editedLines.map(\.id)))
        XCTAssertEqual(fixture.layout.visibleTextRanges, beforeEdit)

        fixture.layoutNow()
        XCTAssertEqual(fixture.layout.visibleTextRanges, fixture.eagerRanges())
        let leftRanges = fixture.layout.visibleTextRanges
        fixture.layout.viewport.origin.x = 300
        fixture.layoutNow()
        XCTAssertEqual(fixture.layout.visibleTextRanges, fixture.eagerRanges())
        XCTAssertNotEqual(fixture.layout.visibleTextRanges, leftRanges,
                          "Spelling must follow the newly exposed columns rather than a previous horizontal viewport.")

        fixture.layout.isLineWrappingEnabled = true
        fixture.layout.scrollViewWidth = 130
        fixture.layout.viewport = CGRect(x: 0, y: 0, width: 130, height: 90)
        fixture.layoutNow()
        XCTAssertEqual(fixture.layout.visibleTextRanges, fixture.eagerRanges())
        let hiddenLine = fixture.lineManager.line(atRow: 1)
        let hiddenRange = NSRange(location: hiddenLine.location, length: hiddenLine.data.totalLength)
        fixture.lineManager.setCollapsedLineRanges([1...1])
        fixture.layoutNow()
        XCTAssertEqual(fixture.layout.visibleTextRanges, fixture.eagerRanges())
        XCTAssertTrue(fixture.layout.visibleTextRanges.allSatisfy { NSIntersectionRange($0, hiddenRange).length == 0 },
                      "Folded text must not remain in a previous layout's spelling request.")

        fixture.layout.viewport = .zero
        fixture.layoutNow()
        XCTAssertTrue(fixture.layout.visibleTextRanges.isEmpty)
        XCTAssertNil(fixture.layout.visibleTextRange)
        fixture.layout.viewport = CGRect(x: 0, y: 0, width: 130, height: 90)
        fixture.layoutNow()
        XCTAssertEqual(fixture.layout.visibleTextRanges, fixture.eagerRanges())
        XCTAssertFalse(fixture.layout.visibleTextRanges.isEmpty)
    }

    private func renderer(string: String, range: NSRange) -> LineFragmentRenderer {
        let attributedString = NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: 20)])
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: range.location, length: range.length))
        let size = CGSize(width: CTLineGetTypographicBounds(line, nil, nil, nil), height: 24)
        let fragment = LineFragment(id: LineFragmentID(lineId: "test", lineFragmentIndex: 0),
                                    index: 0,
                                    visibleRange: range,
                                    line: line,
                                    descent: 5,
                                    baseSize: size,
                                    scaledSize: size,
                                    yPosition: 0)
        return LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: InvisibleCharacterConfiguration())
    }

    private func width(of string: String) -> CGFloat {
        let attributedString = NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: 20)])
        return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributedString), nil, nil, nil))
    }
}

@MainActor
private final class SpellingLayoutFixture {
    let stringView: StringView
    let lineManager: LineManager
    let layout: LayoutManager
    private let parent = UIView(frame: CGRect(x: 0, y: 0, width: 180, height: 90))

    init(text: String) {
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let configuration = InvisibleCharacterConfiguration()
        let highlights = HighlightService(lineManager: lineManager)
        let factory = LineControllerFactory(stringView: stringView, highlightService: highlights,
                                            invisibleCharacterConfiguration: configuration)
        let storage = LineControllerStorage(stringView: stringView, lineControllerFactory: factory)
        let gutter = GutterWidthService(lineManager: lineManager)
        let contentSize = ContentSizeService(lineManager: lineManager, lineControllerStorage: storage,
                                             gutterWidthService: gutter, invisibleCharacterConfiguration: configuration)
        let caret = CaretRectService(stringView: stringView, lineManager: lineManager,
                                     lineControllerStorage: storage, gutterWidthService: gutter)
        let selection = SelectionRectService(lineManager: lineManager, contentSizeService: contentSize,
                                             gutterWidthService: gutter, caretRectService: caret)
        self.stringView = stringView
        self.lineManager = lineManager
        self.layout = LayoutManager(lineManager: lineManager, languageMode: PlainTextInternalLanguageMode(),
                                    stringView: stringView, lineControllerStorage: storage, contentSizeService: contentSize,
                                    gutterWidthService: gutter, caretRectService: caret,
                                    selectionRectService: selection, highlightService: highlights,
                                    invisibleCharacterConfiguration: configuration)
        layout.textInputView = parent
        layout.isLineWrappingEnabled = false
        layout.scrollViewWidth = parent.bounds.width
        layout.viewport = parent.bounds
        contentSize.scrollViewWidth = parent.bounds.width
    }

    func layoutNow() {
        layout.setNeedsLayout()
        layout.layoutIfNeeded()
    }

    /// Read the actual displayed drawing objects, independently of the saved
    /// spelling ranges, using the same directional Core Text mapping as before.
    func eagerRanges() -> [NSRange] {
        displayedFragments(in: parent).sorted { left, right in
            if left.documentLineLocation != right.documentLineLocation {
                return left.documentLineLocation < right.documentLineLocation
            }
            return (left.renderer?.lineFragment.index ?? 0) < (right.renderer?.lineFragment.index ?? 0)
        }.flatMap { view -> [NSRange] in
            guard let renderer = view.renderer else {
                return []
            }
            let fragment = renderer.lineFragment
            let ranges = layout.isLineWrappingEnabled ? [fragment.visibleRange]
                : LineFragmentRenderer.visibleCharacterRanges(
                    in: (layout.viewport.minX - 32) ... (layout.viewport.maxX + 32), lineFragment: fragment)
            return ranges.map { NSRange(location: view.documentLineLocation + $0.location, length: $0.length) }
        }
    }

    private func displayedFragments(in view: UIView) -> [LineFragmentView] {
        view.subviews.flatMap { child -> [LineFragmentView] in
            if let fragment = child as? LineFragmentView {
                return [fragment]
            }
            return displayedFragments(in: child)
        }
    }
}
