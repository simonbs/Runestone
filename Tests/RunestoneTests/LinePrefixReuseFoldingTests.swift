@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

/// Editing a measured wrapped prefix must preserve an unrelated collapsed block,
/// including its row translation and displayed geometry through split/join/undo.
@MainActor
final class LinePrefixReuseFoldingTests: XCTestCase {
    private var windows: [UIWindow] = []

    override func tearDown() {
        for window in windows { window.isHidden = true }
        windows = []
        super.tearDown()
    }

    func testWrappedEditsBeforeFoldPreserveGeometryAndUndo() throws {
        let longLine = "// " + String(repeating: "alpha beta gamma ", count: 400)
        let source = longLine + "\nfunction folded() {\n  work();\n}\nafter();\n"
        let expected = NSMutableString(string: source)
        let location = longLine.utf16.count - 20
        let (view, input) = try makeView(source, collapsedRow: 1)
        prepare(view, input: input, caret: location, headerRow: 1)
        let undo = try XCTUnwrap(input.undoManager)
        undo.removeAllActions()

        input.replace(IndexedRange(location: location, length: 0), withText: "X")
        expected.insert("X", at: location)
        try assertMatchesFresh(view, input: input, expected: expected as String,
                               caret: location + 1, headerRow: 1)

        input.replace(IndexedRange(location: location + 1, length: 0), withText: "\n")
        expected.insert("\n", at: location + 1)
        let splitSource = expected as String
        try assertMatchesFresh(view, input: input, expected: splitSource,
                               caret: location + 2, headerRow: 2)

        undo.removeAllActions()
        input.replace(IndexedRange(location: location + 1, length: 1), withText: "")
        expected.deleteCharacters(in: NSRange(location: location + 1, length: 1))
        try assertMatchesFresh(view, input: input, expected: expected as String,
                               caret: location + 1, headerRow: 1)

        XCTAssertTrue(undo.canUndo)
        undo.undo()
        // Undo restores the pre-join selection as well as the split document.
        try assertMatchesFresh(view, input: input, expected: splitSource,
                               caret: location + 2, headerRow: 2)
    }

    private func makeView(_ text: String, collapsedRow: Int) throws -> (TextView, TextInputView) {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 360, height: 260))
        view.contentInsetAdjustmentBehavior = .never
        view.isAutomaticScrollEnabled = false
        view.isLineWrappingEnabled = true
        view.showLineNumbers = true
        let window = UIWindow(frame: view.frame)
        let host = UIViewController()
        window.rootViewController = host
        host.view.addSubview(view)
        window.isHidden = false
        windows.append(window)
        let language = TreeSitterLanguage(tree_sitter_javascript(), foldsQuery: .init(string: "(statement_block) @fold"))
        view.setState(TextViewState(text: text, language: language))
        view.isCodeFoldingEnabled = true
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.refreshCodeFolding(synchronously: true)
        input.toggleFold(atRow: collapsedRow, animated: false)
        settle(view, input: input)
        return (view, input)
    }

    private func prepare(_ view: TextView, input: TextInputView, caret: Int, headerRow: Int) {
        // Fully measure the visible prefix on both sides of the comparison so
        // legitimate offscreen height estimates cannot masquerade as a regression.
        for row in 0 ..< headerRow {
            let line = input.lineManager.line(atRow: row)
            input.layoutLines(toLocation: line.location + line.data.length)
        }
        view.selectedRange = NSRange(location: caret, length: 0)
        view.scrollRangeToVisible(view.selectedRange)
        settle(view, input: input)
    }

    private func assertMatchesFresh(_ view: TextView, input: TextInputView, expected: String,
                                    caret: Int, headerRow: Int) throws {
        XCTAssertEqual(view.text, expected)
        XCTAssertEqual(view.selectedRange, NSRange(location: caret, length: 0))
        input.refreshCodeFolding(synchronously: true)
        let collapsed = try XCTUnwrap(input.foldingController.collapsedRanges.first)
        XCTAssertEqual(input.foldingController.collapsedRanges.count, 1)
        XCTAssertEqual(collapsed.startRow, headerRow)
        XCTAssertTrue(input.lineManager.isLineHidden(headerRow + 1))
        let (fresh, freshInput) = try makeView(expected, collapsedRow: headerRow)
        defer { fresh.removeFromSuperview() }
        prepare(view, input: input, caret: caret, headerRow: headerRow)
        prepare(fresh, input: freshInput, caret: caret, headerRow: headerRow)
        let actualCaret = input.caretRect(at: caret)
        let freshCaret = freshInput.caretRect(at: caret)
        XCTAssertEqual(actualCaret.minX, freshCaret.minX, accuracy: 0.5)
        XCTAssertEqual(actualCaret.minY, freshCaret.minY, accuracy: 0.5)
        XCTAssertEqual(actualCaret.height, freshCaret.height, accuracy: 0.5)
        let afterRow = collapsed.endRow + 1
        XCTAssertEqual(input.lineManager.line(atRow: afterRow).yPosition,
                       freshInput.lineManager.line(atRow: afterRow).yPosition, accuracy: 0.5)
        XCTAssertEqual(input.lineManager.contentHeight, freshInput.lineManager.contentHeight, accuracy: 0.5)
        for row in collapsed.hiddenStartRow ... collapsed.endRow {
            XCTAssertEqual(input.lineManager.line(atRow: row).data.lineHeight, input.lineManager.estimatedLineHeight,
                           "Hidden text must retain its lazy height estimate.")
        }
    }

    private func settle(_ view: TextView, input: TextInputView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
    }
}
