@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

@MainActor
final class ViewportNavigationEditingTests: XCTestCase {
    func testEditingLongUnicodeLinesMatchesFreshEditorGeometryWithAndWithoutWrapping() throws {
        let language = TreeSitterLanguage(tree_sitter_javascript(), highlightsQuery: .init(string: """
        (string) @string
        (comment) @string
        (number) @number
        """))
        let theme = NavigationHighlightTheme()
        let text = "let value = \"" + String(repeating: "Grøn 😀 אבגד\ttext ", count: 24)
            + "\";\nlet count = 42;\n\n"
        for wrapping in [true, false] {
            let view = makeEditingTextView(wrapping: wrapping)
            view.setState(TextViewState(text: text, theme: theme, language: language))
            let input = try textInput(in: view)
            settleLayout(view, input: input)
            let split = (text as NSString).range(of: "text").location

            // Splitting and immediately joining a token exercises line identity,
            // byte offsets, wrap invalidation, and syntax spanning later lines.
            view.replace(NSRange(location: split, length: 0), withText: "\n")
            let splitText = (text as NSString).replacingCharacters(in: NSRange(location: split, length: 0), with: "\n")
            XCTAssertEqual(view.text, splitText)
            // UIKit selects the preceding character before calling deleteBackward.
            view.selectedRange = NSRange(location: split, length: 1)
            view.deleteBackward()
            XCTAssertEqual(view.text, text)

            let numberRange = (view.text as NSString).range(of: "42")
            let replacement = "7;\n/* changed syntax\non another line */\nlet next = 9"
            view.replaceText(in: BatchReplaceSet(replacements: [.init(range: numberRange, text: replacement)]))
            let replaced = (text as NSString).replacingCharacters(in: numberRange, with: replacement)
            XCTAssertEqual(view.text, replaced)
            view.undoManager?.undo()
            XCTAssertEqual(view.text, text)
            view.undoManager?.redo()
            XCTAssertEqual(view.text, replaced)

            // An open comment changes token fonts beyond the edited line. Insert
            // at the beginning and delete at EOF, including the empty final line.
            view.replace(NSRange(location: 0, length: 0), withText: "/*")
            view.selectedRange = NSRange(location: (view.text as NSString).length - 1, length: 1)
            view.deleteBackward()
            let commented = ("/*" + replaced) as NSString
            let expected = commented.substring(to: commented.length - 1)
            XCTAssertEqual(view.text, expected)
            XCTAssertEqual(view.selectedRange, NSRange(location: (expected as NSString).length, length: 0))
            try assertEditedGeometryMatchesFreshEditor(view, input: input, language: language, theme: theme, wrapping: wrapping)

            // Replace appearance and document before yielding to any queued
            // highlighting completions from the preceding ordinary layout.
            view.contentOffset.y = max(0, view.contentSize.height / 2)
            settleLayout(view, input: input)
            let replacementTheme = DefaultTheme()
            let replacementDocument = "let replacement = \"😀 אבגד\";\n\tlet end = 3;\n"
            view.setState(TextViewState(text: replacementDocument, theme: replacementTheme, language: language))
            XCTAssertEqual(view.text, replacementDocument)
            try assertEditedGeometryMatchesFreshEditor(view, input: input, language: language,
                                                       theme: replacementTheme, wrapping: wrapping)
        }
    }

    private func makeEditingTextView(wrapping: Bool) -> TextView {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        view.contentInsetAdjustmentBehavior = .never
        view.isLineWrappingEnabled = wrapping
        view.isAutomaticScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 11, left: 8, bottom: 13, right: 8)
        return view
    }

    private func assertEditedGeometryMatchesFreshEditor(_ edited: TextView, input: TextInputView,
                                                        language: TreeSitterLanguage, theme: Theme, wrapping: Bool) throws {
        let fresh = makeEditingTextView(wrapping: wrapping)
        fresh.setState(TextViewState(text: edited.text, theme: theme, language: language))
        let freshInput = try textInput(in: fresh)
        fresh.selectedRange = edited.selectedRange
        for (view, textInput) in [(edited, input), (fresh, freshInput)] {
            view.contentOffset = .zero
            settleLayout(view, input: textInput)
            textInput.layoutLines(toLocation: textInput.string.length)
            settleLayout(view, input: textInput)
        }
        XCTAssertEqual(input.lineManager.lineCount, freshInput.lineManager.lineCount)
        XCTAssertEqual(edited.contentSize.width, fresh.contentSize.width, accuracy: 0.5)
        XCTAssertEqual(edited.contentSize.height, fresh.contentSize.height, accuracy: 0.5)
        for row in 0..<input.lineManager.lineCount {
            let line = input.lineManager.line(atRow: row)
            let freshLine = freshInput.lineManager.line(atRow: row)
            XCTAssertEqual(line.data.lineHeight, freshLine.data.lineHeight, accuracy: 0.5)
            for location in [line.location, line.location + line.data.length / 2, line.location + line.data.length] {
                let actual = input.caretRect(at: location)
                let expected = freshInput.caretRect(at: location)
                XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5)
                XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5)
                XCTAssertEqual(actual.height, expected.height, accuracy: 0.5)
            }
        }
        // Both editors revisit the end and start after full measurement, covering
        // cached geometry after mutation as well as the initial settled result.
        for location in [input.string.length, 0] {
            edited.scrollRangeToVisible(NSRange(location: location, length: 0))
            fresh.scrollRangeToVisible(NSRange(location: location, length: 0))
            settleLayout(edited, input: input)
            settleLayout(fresh, input: freshInput)
            XCTAssertEqual(edited.contentOffset.y, fresh.contentOffset.y, accuracy: 0.5)
            XCTAssertEqual(edited.contentOffset.x, fresh.contentOffset.x, accuracy: 0.5)
            try assertVisibleFragmentRenderingMatches(edited, fresh: fresh)
        }
    }

    private func assertVisibleFragmentRenderingMatches(_ edited: TextView, fresh: TextView) throws {
        let actualFragments = visibleFragments(in: edited)
        let expectedFragments = visibleFragments(in: fresh)
        XCTAssertFalse(actualFragments.isEmpty, "The appearance oracle must compare actual visible fragments.")
        XCTAssertEqual(actualFragments.count, expectedFragments.count)
        XCTAssertTrue(actualFragments.contains { CTLineGetGlyphCount($0.renderer!.lineFragment.line) > 0 },
                      "An empty viewport cannot establish matching syntax rendering.")
        for (actual, expected) in zip(actualFragments, expectedFragments) {
            let actualRenderer = try XCTUnwrap(actual.renderer)
            let expectedRenderer = try XCTUnwrap(expected.renderer)
            let key = "line \(actual.documentLineLocation), fragment \(actualRenderer.lineFragment.index)"
            XCTAssertEqual(actual.documentLineLocation, expected.documentLineLocation, key)
            XCTAssertEqual(actualRenderer.lineFragment.index, expectedRenderer.lineFragment.index, key)
            XCTAssertEqual(actualRenderer.lineFragment.visibleRange, expectedRenderer.lineFragment.visibleRange, key)
            XCTAssertEqual(actual.bounds.width, expected.bounds.width, accuracy: 0.5, key)
            XCTAssertEqual(actual.bounds.height, expected.bounds.height, accuracy: 0.5, key)
            let canvasSize = CGSize(width: max(1, ceil(expected.bounds.width)),
                                    height: max(1, ceil(expected.bounds.height)))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let canvas = UIGraphicsImageRenderer(size: canvasSize, format: format)
            func imageData(for renderer: LineFragmentRenderer) throws -> Data {
                let image = canvas.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: canvasSize))
                    renderer.draw(to: context.cgContext, inCanvasOfSize: canvasSize)
                }
                return try XCTUnwrap(image.pngData())
            }
            let actualImage = try imageData(for: actualRenderer)
            let expectedImage = try imageData(for: expectedRenderer)
            XCTAssertTrue(actualImage == expectedImage,
                          "Edited syntax rendering must match a fresh editor for \(key).")
        }
    }

    private func visibleFragments(in view: TextView) -> [LineFragmentView] {
        func descendants(of parent: UIView) -> [LineFragmentView] {
            parent.subviews.flatMap { child in
                if let fragment = child as? LineFragmentView {
                    return [fragment]
                }
                return descendants(of: child)
            }
        }
        return descendants(of: view).filter { fragment in
            !fragment.isHidden && fragment.renderer != nil && fragment.convert(fragment.bounds, to: view).intersects(view.bounds)
        }.sorted { lhs, rhs in
            if lhs.documentLineLocation != rhs.documentLineLocation {
                return lhs.documentLineLocation < rhs.documentLineLocation
            }
            return lhs.renderer!.lineFragment.index < rhs.renderer!.lineFragment.index
        }
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
}
