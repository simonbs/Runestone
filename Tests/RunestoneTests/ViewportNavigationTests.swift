@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

@MainActor
final class ViewportNavigationTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testGoToDistantLineDoesNotMeasureInterveningWrappedLines() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        let middleLine = input.lineManager.line(atRow: 500)
        let estimatedHeight = middleLine.data.lineHeight
        let target = input.lineManager.line(atRow: 999)

        XCTAssertTrue(view.goToLine(999))
        settleLayout(view, input: input)

        XCTAssertEqual(view.selectedRange, NSRange(location: target.location, length: 0))
        XCTAssertEqual(middleLine.data.lineHeight, estimatedHeight,
                       "A distant jump must not typeset the wrapped lines between the old and new viewport.")
        assertCaretVisible(at: target.location, in: view, input: input)
    }

    func testScrollRangeToDocumentEndDoesNotMeasureInterveningWrappedLines() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        let middleLine = input.lineManager.line(atRow: 500)
        let estimatedHeight = middleLine.data.lineHeight
        let end = input.string.length

        view.scrollRangeToVisible(NSRange(location: end, length: 0))
        settleLayout(view, input: input)

        XCTAssertEqual(middleLine.data.lineHeight, estimatedHeight,
                       "Revealing the end must leave unrelated offscreen line heights estimated.")
        assertCaretVisible(at: end, in: view, input: input)
    }

    func testScrollingUpKeepsVisibleTextAnchoredAsWrappedPredecessorsAreMeasured() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        XCTAssertTrue(view.goToLine(999))
        settleLayout(view, input: input)

        // Cross several viewport boundaries so this exercises previously unmeasured
        // predecessors, not only the small margin prepared during navigation.
        for _ in 0..<20 {
            let documentY = view.contentOffset.y - view.textContainerInset.top
            let anchor = try XCTUnwrap(input.lineManager.line(containingYOffset: documentY))
            let oldScreenY = anchor.yPosition - view.contentOffset.y
            let requestedOffset = view.contentOffset.y - 40

            view.contentOffset.y = requestedOffset
            settleLayout(view, input: input)

            assertViewportIsCovered(in: view, input: input)
            XCTAssertEqual(anchor.yPosition - view.contentOffset.y, oldScreenY + 40, accuracy: 0.5,
                           "Resolving wrapped heights above the viewport must not move existing text beyond the requested scroll.")
        }
    }

    func testScrollingIntoOverestimatedWrappedTailKeepsViewportFilled() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        // Wide CJK characters occupy more width than the ASCII remainder. Measuring
        // only this prefix deliberately overestimates the remaining wrapped height.
        view.text = String(repeating: "漢", count: 1_000) + String(repeating: "a", count: 10_000)
            + "\n" + Array(repeating: "following line", count: 100).joined(separator: "\n")
        settleLayout(view, input: input)
        let wrappedLine = input.lineManager.firstLine
        let estimatedHeight = wrappedLine.data.lineHeight

        view.contentOffset.y = estimatedHeight - view.bounds.height
        settleLayout(view, input: input)

        XCTAssertLessThan(wrappedLine.data.lineHeight, estimatedHeight * 0.75,
                          "This fixture must resolve a substantial overestimate to exercise recovery.")
        assertViewportIsCovered(in: view, input: input)
    }

    func testDisjointJumpsRevealWrappedInteriorThenBeginningAndEnd() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        let wrapped = input.lineManager.line(atRow: 900)
        let interior = wrapped.location + wrapped.data.length / 2
        let untouched = input.lineManager.line(atRow: 500)
        let estimatedHeight = untouched.data.lineHeight

        for location in [interior, 0, input.string.length, interior] {
            view.scrollRangeToVisible(NSRange(location: location, length: 0))
            settleLayout(view, input: input)
            assertCaretVisible(at: location, in: view, input: input)
        }

        XCTAssertEqual(untouched.data.lineHeight, estimatedHeight)
    }

    func testDestinationUsesHighlightedFontMetricsBeforeScrolling() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: "(string) @string"))
        let text = "[\n" + Array(repeating: "0,", count: 999).joined(separator: "\n")
            + "\n\"" + String(repeating: "highlighted text ", count: 20) + "\"\n]"
        view.setState(TextViewState(text: text, theme: NavigationHighlightTheme(), language: language))
        settleLayout(view, input: input)
        let end = input.string.length

        view.scrollRangeToVisible(NSRange(location: end, length: 0))
        settleLayout(view, input: input)

        let predecessor = input.lineManager.line(atRow: input.lineManager.lineCount - 2)
        XCTAssertGreaterThan(predecessor.data.lineHeight, view.bounds.height,
                             "The highlighted predecessor must wrap beyond the viewport to exercise metric changes.")
        assertCaretVisible(at: end, in: view, input: input)
        let screenY = input.caretRect(at: end).minY - view.contentOffset.y
        settleLayout(view, input: input)
        XCTAssertEqual(input.caretRect(at: end).minY - view.contentOffset.y, screenY, accuracy: 0.5,
                       "Applying token fonts must not displace the destination on the following layout pass.")
    }

    func testRangeAcrossWrappedLineBoundaryRevealsBothEndpoints() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        let first = input.lineManager.line(atRow: 900)
        let second = input.lineManager.line(atRow: 901)
        let start = first.location + first.data.length - 8
        let end = second.location + 8

        view.scrollRangeToVisible(NSRange(location: start, length: end - start))
        settleLayout(view, input: input)

        assertCaretVisible(at: start, in: view, input: input)
        assertCaretVisible(at: end, in: view, input: input)
    }

    func testUnwrappedEndJumpAndUpwardScrollingPreserveGeometry() throws {
        let view = try makeTextView(isLineWrappingEnabled: false)
        let input = try textInput(in: view)
        let longLine = input.lineManager.line(atRow: 900)
        let interior = longLine.location + longLine.data.length / 2
        view.scrollRangeToVisible(NSRange(location: interior, length: 0))
        settleLayout(view, input: input)
        assertCaretVisible(at: interior, in: view, input: input)
        let interiorRect = input.convert(input.caretRect(at: interior), to: view)
        XCTAssertGreaterThan(view.contentOffset.x, 0)
        XCTAssertGreaterThanOrEqual(interiorRect.minX, view.bounds.minX - 0.5)
        XCTAssertLessThanOrEqual(interiorRect.maxX, view.bounds.maxX + 0.5)

        let end = input.string.length
        view.scrollRangeToVisible(NSRange(location: end, length: 0))
        settleLayout(view, input: input)
        assertCaretVisible(at: end, in: view, input: input)

        for _ in 0..<8 {
            let documentY = view.contentOffset.y - view.textContainerInset.top
            let anchor = try XCTUnwrap(input.lineManager.line(containingYOffset: documentY))
            let oldScreenY = anchor.yPosition - view.contentOffset.y
            view.contentOffset.y -= 40
            settleLayout(view, input: input)

            XCTAssertEqual(anchor.yPosition - view.contentOffset.y, oldScreenY + 40, accuracy: 0.5)
            assertViewportIsCovered(in: view, input: input)
        }
    }

    func testChangingWrappingNearDocumentEndCanRevealDestinationAndScrollUp() throws {
        let view = try makeTextView()
        let input = try textInput(in: view)
        let end = input.string.length
        view.scrollRangeToVisible(NSRange(location: end, length: 0))
        settleLayout(view, input: input)

        // Mode changes invalidate cached heights. Navigation must use the new
        // wrapping metrics even when the previous viewport was near the end.
        for wrappingEnabled in [false, true, false, true] {
            view.isLineWrappingEnabled = wrappingEnabled
            view.scrollRangeToVisible(NSRange(location: end, length: 0))
            settleLayout(view, input: input)
            assertCaretVisible(at: end, in: view, input: input)

            view.contentOffset.y -= 40
            settleLayout(view, input: input)
            assertViewportIsCovered(in: view, input: input)
        }
    }

    /// Catch missing or overlapping fragment views while new wrapped lines enter from above.
    private func assertViewportIsCovered(in view: TextView, input: TextInputView,
                                         file: StaticString = #filePath, line: UInt = #line) {
        func fragments(in parent: UIView) -> [LineFragmentView] {
            parent.subviews.flatMap { child in
                if let fragment = child as? LineFragmentView {
                    return [fragment]
                }
                return fragments(in: child)
            }
        }
        let frames = fragments(in: input).map { $0.convert($0.bounds, to: view) }
            .sorted { $0.minY < $1.minY }
        XCTAssertFalse(frames.isEmpty, file: file, line: line)
        guard let first = frames.first, let last = frames.last else {
            return
        }
        XCTAssertLessThanOrEqual(first.minY, view.bounds.minY + 0.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(last.maxY, view.bounds.maxY - 0.5, file: file, line: line)
        for (previous, next) in zip(frames, frames.dropFirst()) {
            XCTAssertEqual(previous.maxY, next.minY, accuracy: 0.5,
                           "Visible fragments must meet without gaps or overlaps.", file: file, line: line)
        }
    }

    private func makeTextView(isLineWrappingEnabled: Bool = true) throws -> TextView {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        view.contentInsetAdjustmentBehavior = .never
        view.isLineWrappingEnabled = isLineWrappingEnabled
        view.isAutomaticScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 11, left: 8, bottom: 13, right: 8)
        let window = UIWindow(frame: view.frame)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(view)
        window.isHidden = false
        self.window = window
        view.layoutIfNeeded()
        let wrappedLine = String(repeating: "wrapped text ", count: 20)
        view.text = Array(repeating: wrappedLine, count: 999).joined(separator: "\n") + "\nlast line"
        let input = try textInput(in: view)
        settleLayout(view, input: input)
        return view
    }

    private func textInput(in view: TextView) throws -> TextInputView {
        try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
    }

    private func settleLayout(_ view: TextView, input: TextInputView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
    }

    private func assertCaretVisible(at location: Int, in view: TextView, input: TextInputView,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let caret = input.caretRect(at: location)
        let screenRect = input.convert(caret, to: view)
        XCTAssertGreaterThanOrEqual(screenRect.minY, view.bounds.minY - 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(screenRect.maxY, view.bounds.maxY + 0.5, file: file, line: line)
    }
}

private final class NavigationHighlightTheme: Theme {
    let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor = UIColor.black
    let gutterBackgroundColor = UIColor.white
    let gutterHairlineColor = UIColor.gray
    let lineNumberColor = UIColor.gray
    let lineNumberFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    let selectedLineBackgroundColor = UIColor.clear
    let selectedLinesLineNumberColor = UIColor.black
    let selectedLinesGutterBackgroundColor = UIColor.white
    let invisibleCharactersColor = UIColor.gray
    let pageGuideHairlineColor = UIColor.gray
    let pageGuideBackgroundColor = UIColor.white
    let markedTextBackgroundColor = UIColor.yellow

    func textColor(for highlightName: String) -> UIColor? {
        nil
    }

    func font(for highlightName: String) -> UIFont? {
        highlightName == "string" ? .monospacedSystemFont(ofSize: 34, weight: .regular) : nil
    }
}
