// swiftlint:disable file_length
import CoreText
@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

/// Opt-in 25 MiB integration oracle. Each checkpoint reparses the current text in
/// a fresh editor and compares actual visible drawing objects after distant edits.
/// This verifies settled output, not every asynchronous frame or keyboard input.
@MainActor
final class LargeFileCorrectnessTests: XCTestCase {
    func testShortLinesWrapped() throws { try verify(longLines: false, wrapping: true) }
    func testShortLinesUnwrapped() throws { try verify(longLines: false, wrapping: false) }
    func testLongLinesWrapped() throws { try verify(longLines: true, wrapping: true) }
    func testLongLinesUnwrapped() throws { try verify(longLines: true, wrapping: false) }
    func testLongASCIILinesWrapped() throws { try verify(longLines: true, wrapping: true, asciiEligible: true) }
    func testLongASCIILinesUnwrapped() throws { try verify(longLines: true, wrapping: false, asciiEligible: true) }
    func testLongUnbrokenASCIILinesWrapped() throws {
        try verify(longLines: true, wrapping: true, asciiEligible: true, unbrokenASCII: true)
    }
    func testLongUnbrokenASCIILinesUnwrapped() throws {
        try verify(longLines: true, wrapping: false, asciiEligible: true, unbrokenASCII: true)
    }

    // swiftlint:disable:next function_body_length
    private func verify(longLines: Bool, wrapping: Bool, asciiEligible: Bool = false, unbrokenASCII: Bool = false) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1 to run the large-file rendering oracle.")
        let fixture = makeFixture(longLines: longLines, asciiEligible: asciiEligible, unbrokenASCII: unbrokenASCII)
        XCTAssertGreaterThanOrEqual(fixture.utf8.count, 25 * 1_024 * 1_024)
        let expected = NSMutableString(string: fixture)
        let query = asciiEligible ? """
        ((string) @string (#not-match? @string "X"))
        ((string) @changed (#match? @changed "X"))
        (number) @number
        """ : """
        (string) @string
        (number) @number
        """
        let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: query))
        let theme: LargeFileOracleTheme
        if asciiEligible {
            theme = LargeFileOracleTheme(regularASCIIFont: try XCTUnwrap(UIFont(name: "Menlo-Regular", size: 14)))
        } else {
            theme = LargeFileOracleTheme()
        }
        let view = makeView(wrapping: wrapping)
        view.setState(TextViewState(text: fixture, theme: theme, language: language))
        let input = try textInput(in: view)
        defer { view.text = "" }
        settle(view, input: input)
        let middleLine = input.lineManager.line(atRow: input.lineManager.lineCount / 2)
        let insertion: Int
        if longLines {
            let suffixText = unbrokenASCII ? "\"," : "\", 123],"
            let suffix = expected.range(of: suffixText, options: .backwards,
                                        range: NSRange(location: middleLine.location, length: middleLine.data.length))
            let closingQuote = try XCTUnwrap(suffix.location == NSNotFound ? nil : suffix.location)
            // Edit immediately before the final ASCII payload character, inside
            // the string. This forces reflow of the long measured prefix after
            // character insertion, splitting and joining near the logical line end.
            insertion = closingQuote - 1
        } else {
            // After ASCII "target", before the Unicode/punctuation payload.
            insertion = middleLine.location + 10
        }
        prepareViewport(view, input: input, location: insertion)

        func checkpoint(_ name: String, at location: Int) throws {
            XCTAssertEqual(input.string as String, expected as String, name)
            try autoreleasepool {
                try compareWithFresh(view, input: input, expected: expected, location: location,
                                     language: language)
            }
            print("LARGE_FILE_CORRECTNESS checkpoint=\(name) long=\(longLines) wrapping=\(wrapping) utf16=\(input.string.length)")
        }

        if asciiEligible {
            // Reused prefix geometry must still receive new colors when a late
            // edit changes the entire string capture's predicate result.
            XCTAssertEqual(try syntaxColor(at: insertion - 5, in: view), .red)
        }
        view.selectedRange = NSRange(location: insertion, length: 0)
        view.insertText("X")
        expected.insert("X", at: insertion)
        XCTAssertEqual(view.selectedRange, NSRange(location: insertion + 1, length: 0))
        try checkpoint("character", at: insertion + 1)
        if asciiEligible {
            XCTAssertEqual(try syntaxColor(at: insertion - 5, in: view), .blue)
        }

        // Public replacement isolates a literal split from indentation policy.
        // The separate performance harness covers typed insertText("\n").
        let split = insertion + 1
        view.replace(NSRange(location: split, length: 0), withText: "\n")
        expected.insert("\n", at: split)
        try checkpoint("split", at: split + 1)

        view.selectedRange = NSRange(location: split, length: 1)
        view.deleteBackward()
        expected.deleteCharacters(in: NSRange(location: split, length: 1))
        XCTAssertEqual(view.selectedRange, NSRange(location: split, length: 0))
        try checkpoint("join", at: split)
        if asciiEligible {
            XCTAssertEqual(try syntaxColor(at: insertion - 5, in: view), .blue)
        }

        let lineToDelete = input.lineManager.line(atRow: input.lineManager.lineCount - 3)
        let deletion = NSRange(location: lineToDelete.location, length: lineToDelete.data.totalLength)
        let removed = expected.substring(with: deletion)
        prepareViewport(view, input: input, location: deletion.location + 10)
        let undo = try XCTUnwrap(view.undoManager)
        undo.removeAllActions()
        view.selectedRange = deletion
        view.deleteBackward()
        expected.deleteCharacters(in: deletion)
        XCTAssertEqual(view.selectedRange, NSRange(location: deletion.location, length: 0))
        try checkpoint("delete-line", at: deletion.location)

        XCTAssertTrue(undo.canUndo)
        undo.undo()
        expected.insert(removed, at: deletion.location)
        XCTAssertEqual(view.selectedRange, deletion)
        try checkpoint("undo-line-deletion", at: deletion.location + 10)

        XCTAssertTrue(undo.canRedo)
        undo.redo()
        expected.deleteCharacters(in: deletion)
        XCTAssertEqual(view.selectedRange, NSRange(location: deletion.location, length: 0))
        try checkpoint("redo-line-deletion", at: deletion.location)
    }

    private func compareWithFresh(_ edited: TextView, input: TextInputView, expected: NSString, location: Int,
                                  language: TreeSitterLanguage) throws {
        let fresh = makeView(wrapping: edited.isLineWrappingEnabled)
        fresh.setState(TextViewState(text: expected as String, theme: edited.theme, language: language))
        let freshInput = try textInput(in: fresh)
        defer { fresh.text = "" }
        let selection = edited.selectedRange
        fresh.selectedRange = selection
        prepareViewport(edited, input: input, location: location)
        prepareViewport(fresh, input: freshInput, location: location)
        XCTAssertEqual(edited.selectedRange, selection)
        XCTAssertEqual(input.lineManager.lineCount, freshInput.lineManager.lineCount)
        // Offscreen line heights are estimates and legitimately differ with visit
        // history. Compare actual viewport geometry relative to the same caret.
        let actualCaret = screenCaret(at: location, view: edited, input: input)
        let expectedCaret = screenCaret(at: location, view: fresh, input: freshInput)
        XCTAssertEqual(actualCaret.minX, expectedCaret.minX, accuracy: 0.5)
        XCTAssertEqual(actualCaret.minY, expectedCaret.minY, accuracy: 0.5)
        XCTAssertEqual(actualCaret.height, expectedCaret.height, accuracy: 0.5)
        try compareVisibleFragments(edited, input: input, fresh: fresh, freshInput: freshInput)
    }

    private func prepareViewport(_ view: TextView, input: TextInputView, location: Int) {
        view.contentOffset = .zero
        settle(view, input: input)
        view.scrollRangeToVisible(NSRange(location: location, length: 0))
        settle(view, input: input)
        var isStable = false
        var previousState: [CGFloat]?
        var diagnostics: [String] = []
        for _ in 0..<3 {
            // Force final syntax/font geometry before choosing the common viewport,
            // including neighbors exposed by the previous centering pass.
            input.layoutLines(toLocation: location)
            settle(view, input: input)
            let caret = input.convert(input.caretRect(at: location), to: view)
            // ContentSizeService rounds the document height up. Different legitimate
            // offscreen measurement histories therefore produce different subpixel
            // slack at EOF. Exclude that rounding slack when placing the oracle's
            // viewport; this remains within the actual scrollable content bounds.
            let contentHeight = input.lineManager.contentHeight + view.textContainerInset.top + view.textContainerInset.bottom
            let maximum = max(0, contentHeight - view.bounds.height)
            let targetY = min(maximum, max(0, caret.midY - view.bounds.height / 2))
            view.contentOffset.y = targetY
            settle(view, input: input)
            let actualCaret = screenCaret(at: location, view: view, input: input)
            let state = [view.contentOffset.x, view.contentOffset.y, actualCaret.minX, actualCaret.minY,
                         actualCaret.width, actualCaret.height]
            diagnostics.append("target=\(targetY) actual=\(view.contentOffset.y) caret=\(actualCaret) height=\(input.lineManager.contentHeight)")
            // Observe actual local geometry across repeated identical requests.
            // Offscreen estimates can continue to change without moving this viewport.
            // UIScrollView/layout may adjust the requested fractional offset.
            if let previousState, zip(state, previousState).allSatisfy({ pair in abs(pair.0 - pair.1) < 0.001 }) {
                isStable = true
                break
            }
            previousState = state
        }
        XCTAssertTrue(isStable, "The oracle viewport must stabilize after final synchronous font layout: \(diagnostics)")
    }

    // The checks operate on production renderer state, not on a screenshot of an
    // empty launch. Pixel canvases are clipped to the actual horizontal viewport.
    private struct FragmentKey: Hashable {
        let lineLocation: Int
        let fragmentIndex: Int
    }

    private struct FragmentSnapshot {
        let renderer: LineFragmentRenderer
        let frame: CGRect
    }

    private func compareVisibleFragments(_ edited: TextView, input: TextInputView,
                                         fresh: TextView, freshInput: TextInputView) throws {
        let actualAll = renderedFragments(in: edited)
        let expectedAll = renderedFragments(in: fresh)
        let actual = actualAll.filter { $0.convert($0.bounds, to: edited).intersects(edited.bounds) }
        let expected = expectedAll.filter { $0.convert($0.bounds, to: fresh).intersects(fresh.bounds) }
        XCTAssertFalse(actual.isEmpty)
        XCTAssertTrue(actual.contains { hasSyntaxColor($0) }, "The oracle must compare actual syntax colors.")
        assertViewportCoverage(actual, view: edited, input: input)
        assertViewportCoverage(expected, view: fresh, input: freshInput)
        let actualKeys = Set(actual.map(fragmentKey))
        let expectedKeys = Set(expected.map(fragmentKey))
        let actualByKey = Dictionary(grouping: actualAll, by: fragmentKey)
        let expectedByKey = Dictionary(grouping: expectedAll, by: fragmentKey)
        for key in actualKeys.union(expectedKeys) {
            if actualKeys.contains(key) != expectedKeys.contains(key) {
                // UIScrollView rounds applied offsets. A subpixel edge strip can
                // enter only one viewport within the existing geometry tolerance.
                let candidates = actualKeys.contains(key) ? actualByKey[key] : expectedByKey[key]
                let visibleView = try XCTUnwrap(candidates?.first)
                let viewport = actualKeys.contains(key) ? edited : fresh
                let visibleHeight = visibleView.convert(visibleView.bounds, to: viewport).intersection(viewport.bounds).height
                XCTAssertLessThanOrEqual(visibleHeight, 0.5, "Only a subpixel viewport-edge strip may differ in visibility.")
            }
            let actualSnapshot = try snapshot(key, candidates: actualByKey[key], view: edited, input: input)
            let expectedSnapshot = try snapshot(key, candidates: expectedByKey[key], view: fresh, input: freshInput)
            try compareFragment(actualSnapshot, in: edited, expected: expectedSnapshot, fresh: fresh)
        }
    }

    private func snapshot(_ key: FragmentKey, candidates: [LineFragmentView]?, view: TextView,
                          input: TextInputView) throws -> FragmentSnapshot {
        if let candidates {
            XCTAssertEqual(candidates.count, 1)
            let fragment = try XCTUnwrap(candidates.first)
            return FragmentSnapshot(renderer: try XCTUnwrap(fragment.renderer),
                                    frame: fragment.convert(fragment.bounds, to: view))
        }
        // A just-offscreen fragment can lose its UIView while retaining its real
        // controller/renderer. Read those existing objects without layout or fresh
        // typesetting. Reflection is confined to this oracle because storage and
        // renderer ownership are private; absence is an assertion failure.
        let storage = try XCTUnwrap(Mirror(reflecting: input).children.compactMap { $0.value as? LineControllerStorage }.first)
        let line = try XCTUnwrap(input.lineManager.line(containingCharacterAt: key.lineLocation))
        XCTAssertEqual(line.location, key.lineLocation)
        let controller = try XCTUnwrap(storage[line.id])
        let cached = try XCTUnwrap(Mirror(reflecting: controller).children.compactMap { child in
            child.value as? [LineFragmentID: LineFragmentController]
        }.first)
        let existingController = cached.values.first { $0.lineFragment.index == key.fragmentIndex }
        let fragmentController = try XCTUnwrap(existingController, "Missing cached controller for \(key)")
        let renderer = try XCTUnwrap(Mirror(reflecting: fragmentController).children.compactMap { $0.value as? LineFragmentRenderer }.first)
        let fragment = renderer.lineFragment
        XCTAssertFalse(view.showLineNumbers, "This oracle fixture has no gutter when reconstructing an offscreen frame.")
        // Same frame formula as LayoutManager.layoutLineFragmentView, with the
        // fixture's disabled gutter. No new view or layout is created.
        let frame = CGRect(x: view.textContainerInset.left,
                           y: view.textContainerInset.top + line.yPosition + fragment.yPosition,
                           width: view.contentSize.width - view.textContainerInset.left - view.textContainerInset.right,
                           height: fragment.scaledSize.height)
        return FragmentSnapshot(renderer: renderer, frame: input.convert(frame, to: view))
    }

    private func fragmentKey(_ fragment: LineFragmentView) -> FragmentKey {
        FragmentKey(lineLocation: fragment.documentLineLocation, fragmentIndex: fragment.renderer!.lineFragment.index)
    }

    private func compareFragment(_ actual: FragmentSnapshot, in edited: TextView,
                                 expected: FragmentSnapshot, fresh: TextView) throws {
        let actualFragment = actual.renderer.lineFragment
        let expectedFragment = expected.renderer.lineFragment
        XCTAssertEqual(actualFragment.visibleRange, expectedFragment.visibleRange)
        XCTAssertEqual(actualFragment.hiddenLength, expectedFragment.hiddenLength)
        XCTAssertEqual(actualFragment.baseSize, expectedFragment.baseSize)
        let actualFrame = actual.frame.offsetBy(dx: -edited.bounds.minX, dy: -edited.bounds.minY)
        let expectedFrame = expected.frame.offsetBy(dx: -fresh.bounds.minX, dy: -fresh.bounds.minY)
        XCTAssertEqual(actualFrame.minX, expectedFrame.minX, accuracy: 0.5)
        XCTAssertEqual(actualFrame.minY, expectedFrame.minY, accuracy: 0.5)
        XCTAssertEqual(actualFrame.height, expectedFrame.height, accuracy: 0.5)
        compareRuns(actualFragment.line, expected: expectedFragment.line)
        XCTAssertEqual(try pixels(actual, in: edited), try pixels(expected, in: fresh),
                       "Edited visible rendering must match freshly parsed styled text.")
    }

    private func assertViewportCoverage(_ fragments: [LineFragmentView], view: TextView, input: TextInputView) {
        let frames = fragments.map { $0.convert($0.bounds, to: view) }.sorted { $0.minY < $1.minY }
        XCTAssertFalse(frames.isEmpty)
        guard let first = frames.first, let last = frames.last else {
            return
        }
        let finalLine = input.lineManager.lastLine
        // The final empty logical row has caret height but no renderer.
        let renderedHeight = finalLine.data.totalLength == 0 ? 0 : finalLine.data.lineHeight
        let documentBottom = view.textContainerInset.top + finalLine.yPosition + renderedHeight
        XCTAssertLessThanOrEqual(first.minY, max(view.bounds.minY, view.textContainerInset.top) + 0.5)
        XCTAssertGreaterThanOrEqual(last.maxY, min(view.bounds.maxY, documentBottom) - 0.5)
        for (previous, next) in zip(frames, frames.dropFirst()) {
            XCTAssertEqual(previous.maxY, next.minY, accuracy: 0.5, "Visible text must have no gaps or overlaps.")
        }
    }

}

private extension LargeFileCorrectnessTests {
    private func compareRuns(_ actual: CTLine, expected: CTLine) {
        let actualRuns = CTLineGetGlyphRuns(actual) as? [CTRun] ?? []
        let expectedRuns = CTLineGetGlyphRuns(expected) as? [CTRun] ?? []
        XCTAssertEqual(actualRuns.count, expectedRuns.count)
        for (actualRun, expectedRun) in zip(actualRuns, expectedRuns) {
            XCTAssertEqual(CTRunGetAttributes(actualRun) as NSDictionary, CTRunGetAttributes(expectedRun) as NSDictionary)
            let actualRange = CTRunGetStringRange(actualRun)
            let expectedRange = CTRunGetStringRange(expectedRun)
            XCTAssertEqual(actualRange.location, expectedRange.location)
            XCTAssertEqual(actualRange.length, expectedRange.length)
            let count = CTRunGetGlyphCount(actualRun)
            XCTAssertEqual(count, CTRunGetGlyphCount(expectedRun))
            guard count == CTRunGetGlyphCount(expectedRun) else { continue }
            var actualGlyphs = [CGGlyph](repeating: 0, count: count)
            var expectedGlyphs = actualGlyphs
            var actualPositions = [CGPoint](repeating: .zero, count: count)
            var expectedPositions = actualPositions
            CTRunGetGlyphs(actualRun, CFRange(location: 0, length: 0), &actualGlyphs)
            CTRunGetGlyphs(expectedRun, CFRange(location: 0, length: 0), &expectedGlyphs)
            CTRunGetPositions(actualRun, CFRange(location: 0, length: 0), &actualPositions)
            CTRunGetPositions(expectedRun, CFRange(location: 0, length: 0), &expectedPositions)
            XCTAssertEqual(actualGlyphs, expectedGlyphs)
            XCTAssertEqual(actualPositions, expectedPositions)
        }
    }

    private func pixels(_ fragment: FragmentSnapshot, in view: TextView) throws -> Data {
        let renderer = fragment.renderer
        let frame = fragment.frame
        // Include the full fragment height even when one viewport clips a tiny
        // vertical edge strip; horizontal clipping stays identical to the viewport.
        let visibleMinX = max(frame.minX, view.bounds.minX)
        let visibleWidth = max(0, min(frame.maxX, view.bounds.maxX) - visibleMinX)
        let size = CGSize(width: max(1, ceil(visibleWidth)), height: max(1, ceil(frame.height)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return try XCTUnwrap(UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: -(visibleMinX - frame.minX), y: 0)
            renderer.draw(to: context.cgContext, inCanvasOfSize: frame.size)
        }.pngData())
    }

    private func hasSyntaxColor(_ fragment: LineFragmentView) -> Bool {
        guard let line = fragment.renderer?.lineFragment.line else {
            return false
        }
        return (CTLineGetGlyphRuns(line) as? [CTRun] ?? []).contains { run in
            let color = (CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.foregroundColor] as? UIColor
            return color == .red || color == .blue
        }
    }

    private func syntaxColor(at location: Int, in view: TextView) throws -> UIColor {
        let colors: [UIColor] = renderedFragments(in: view).flatMap { fragment -> [UIColor] in
            guard let line = fragment.renderer?.lineFragment else {
                return []
            }
            let local = location - fragment.documentLineLocation
            guard NSLocationInRange(local, line.visibleRange) else {
                return []
            }
            return (CTLineGetGlyphRuns(line.line) as? [CTRun] ?? []).compactMap { run -> UIColor? in
                let range = CTRunGetStringRange(run)
                guard local >= range.location, local < range.location + range.length else {
                    return nil
                }
                return (CTRunGetAttributes(run) as NSDictionary)[NSAttributedString.Key.foregroundColor] as? UIColor
            }
        }
        XCTAssertEqual(colors.count, 1, "The color assertion must inspect the actual unchanged prefix glyph run.")
        return try XCTUnwrap(colors.first)
    }

    private func screenCaret(at location: Int, view: TextView, input: TextInputView) -> CGRect {
        input.convert(input.caretRect(at: location), to: view).offsetBy(dx: -view.bounds.minX, dy: -view.bounds.minY)
    }

    private func renderedFragments(in view: TextView) -> [LineFragmentView] {
        func descendants(of parent: UIView) -> [LineFragmentView] {
            parent.subviews.flatMap { child in
                if let fragment = child as? LineFragmentView {
                    return [fragment]
                }
                return descendants(of: child)
            }
        }
        return descendants(of: view).filter { fragment in
            !fragment.isHidden && fragment.renderer != nil
        }.sorted { lhs, rhs in
            if lhs.documentLineLocation != rhs.documentLineLocation {
                return lhs.documentLineLocation < rhs.documentLineLocation
            }
            return lhs.renderer!.lineFragment.index < rhs.renderer!.lineFragment.index
        }
    }

    private func makeFixture(longLines: Bool, asciiEligible: Bool = false, unbrokenASCII: Bool = false) -> String {
        if unbrokenASCII {
            // Quoted JSON rows isolate the run-scoped cluster fast path: spaces,
            // opening quote, 60,000 alphanumeric characters, closing quote/comma/LF.
            // The regular-font color predicate still exercises nonlocal recoloring
            // of the unchanged prefix after edits near the run's end.
            let payload = String(repeating: "a", count: 60_000)
            let line = "  \"\(payload)\",\n"
            let count = (25 * 1_024 * 1_024 + line.utf8.count - 1) / line.utf8.count
            return "[\n" + String(repeating: line, count: count - 1) + String(line.dropLast(2)) + "\n]\n"
        }
        let phrase = asciiEligible ? "target alpha beta gamma /path.file <> (); value=123 "
            : "target Grøn café e\u{301} 😀 אבג العربية /path.file <> (); "
        let targetBytes = longLines ? 60_000 : 128
        let repeated = String(repeating: phrase, count: max(1, (targetBytes - 13) / phrase.utf8.count))
        let payload = repeated + String(repeating: "a", count: max(0, targetBytes - 13 - repeated.utf8.count))
        let line = "  [\"\(payload)\", 123],\n"
        let count = (25 * 1_024 * 1_024 + line.utf8.count - 1) / line.utf8.count
        return "[\n" + String(repeating: line, count: count - 1) + String(line.dropLast(2)) + "\n]\n"
    }

    private func makeView(wrapping: Bool) -> TextView {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        view.contentInsetAdjustmentBehavior = .never
        view.isLineWrappingEnabled = wrapping
        view.isAutomaticScrollEnabled = false
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return view
    }

    private func textInput(in view: TextView) throws -> TextInputView {
        try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
    }

    private func settle(_ view: TextView, input: TextInputView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
    }
}

private final class LargeFileOracleTheme: Theme {
    let font: UIFont
    private let usesUniformASCIIStyle: Bool

    init(regularASCIIFont: UIFont? = nil) {
        font = regularASCIIFont ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        usesUniformASCIIStyle = regularASCIIFont != nil
    }
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

    func highlightStyle(for highlightName: String) -> HighlightStyle? {
        if usesUniformASCIIStyle {
            switch highlightName {
            case "string":
                return HighlightStyle(textColor: .red, font: font)
            case "number", "changed":
                return HighlightStyle(textColor: .blue, font: font)
            default:
                return nil
            }
        }
        switch highlightName {
        case "string":
            return HighlightStyle(textColor: .red, font: .monospacedSystemFont(ofSize: 16, weight: .regular))
        case "number":
            return HighlightStyle(textColor: .blue, font: .monospacedSystemFont(ofSize: 18, weight: .bold), backgroundColor: .yellow)
        default:
            return nil
        }
    }

    func textColor(for highlightName: String) -> UIColor? { nil }
}
