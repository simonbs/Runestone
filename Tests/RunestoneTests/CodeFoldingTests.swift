@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

@MainActor
// swiftlint:disable:next type_body_length
final class CodeFoldingTests: XCTestCase {
    private var window: UIWindow?

    private let source = """
    const before = 0;
    function first() {
      if (true) {
        work();
      }
    }
    const after = 1;
    """

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testFoldingIsOptInAndDoesNotHideTextWhenDisabled() throws {
        let (view, input) = try makeTextView(enabled: false)

        XCTAssertFalse(view.isCodeFoldingEnabled)
        input.refreshCodeFolding(synchronously: true)
        input.toggleFold(atRow: 1, animated: false)
        settle(view, input: input)

        XCTAssertEqual(view.text, source)
        XCTAssertTrue(input.lineManager.foldedLineProjection.spans.isEmpty)
        XCTAssertTrue(foldingButtons(in: input.gutterContainerView).isEmpty)
    }

    func testCollapseChangesGeometryWithoutEditingDocumentOrUndoHistory() throws {
        let (view, input) = try makeTextView()
        let undo = try XCTUnwrap(input.undoManager)
        undo.removeAllActions()
        let originalLineCount = input.lineManager.lineCount
        let originalHeight = input.lineManager.contentHeight
        let header = input.lineManager.line(atRow: 1)
        let following = input.lineManager.line(atRow: 6)

        input.toggleFold(atRow: 1, animated: false)
        settle(view, input: input)

        XCTAssertEqual(view.text, source)
        XCTAssertEqual(input.lineManager.lineCount, originalLineCount)
        XCTAssertFalse(undo.canUndo, "A view-state change must not add a text undo operation.")
        XCTAssertTrue(input.lineManager.isLineHidden(3))
        XCTAssertLessThan(input.lineManager.contentHeight, originalHeight)
        XCTAssertEqual(following.yPosition, header.yPosition + header.data.lineHeight, accuracy: 0.5)
        XCTAssertEqual(input.lineManager.line(containingYOffset: following.yPosition)?.id, following.id)

        input.toggleFold(atRow: 1, animated: false)
        settle(view, input: input)
        XCTAssertEqual(input.lineManager.contentHeight, originalHeight, accuracy: 0.5)
        XCTAssertFalse(undo.canUndo)
    }

    func testReopeningParentRetainsCollapsedChild() throws {
        let (view, input) = try makeTextView()
        input.toggleFold(atRow: 2, animated: false)
        input.toggleFold(atRow: 1, animated: false)
        settle(view, input: input)
        XCTAssertTrue(input.lineManager.isLineHidden(2))

        input.toggleFold(atRow: 1, animated: false)
        settle(view, input: input)

        XCTAssertFalse(input.lineManager.isLineHidden(2))
        XCTAssertTrue(input.lineManager.isLineHidden(3))
        XCTAssertTrue(input.lineManager.isLineHidden(4))
        XCTAssertFalse(input.lineManager.isLineHidden(5))
        XCTAssertEqual(foldingButtons(in: input.gutterContainerView).first { button in
            button.accessibilityIdentifier == "Runestone.Fold.2"
        }?.accessibilityValue, "Collapsed")
    }

    func testKeyboardMovementSkipsCollapsedLinesInBothDirections() throws {
        let (_, input) = try makeTextView()
        input.toggleFold(atRow: 1, animated: false)
        let header = input.lineManager.line(atRow: 1)
        let following = input.lineManager.line(atRow: 6)
        let headerEnd = header.location + header.data.length

        XCTAssertEqual(try destination(in: input, from: header.location, direction: .down), following.location)
        XCTAssertEqual(try destination(in: input, from: following.location, direction: .up), header.location)
        XCTAssertEqual(try destination(in: input, from: headerEnd, direction: .right), following.location)
        XCTAssertEqual(try destination(in: input, from: following.location, direction: .left), headerEnd)
        XCTAssertTrue(input.lineManager.isLineHidden(3), "Ordinary movement past a fold must not expand it.")
    }

    func testMovingRightOrDownPastFoldAtEndOfDocumentStaysOnVisibleHeader() throws {
        let (view, input) = try makeTextView(text: "function final() {\n  body();\n}")
        input.toggleFold(atRow: 0, animated: false)
        settle(view, input: input)
        let header = input.lineManager.firstLine
        let headerEnd = header.location + header.data.length

        XCTAssertEqual(try destination(in: input, from: headerEnd, direction: .right), headerEnd)
        XCTAssertEqual(try destination(in: input, from: headerEnd, direction: .down), headerEnd)
        XCTAssertTrue(input.lineManager.isLineHidden(1))
        XCTAssertTrue(input.lineManager.isLineHidden(2))
        XCTAssertEqual(input.lineManager.line(containingYOffset: input.lineManager.contentHeight)?.id, header.id)
    }

    func testHorizontalMovementAcrossCRLFSkipsCollapsedBody() throws {
        let text = source.replacingOccurrences(of: "\n", with: "\r\n")
        let (_, input) = try makeTextView(text: text)
        input.toggleFold(atRow: 1, animated: false)
        let header = input.lineManager.line(atRow: 1)
        let following = input.lineManager.line(atRow: 6)
        let headerEnd = header.location + header.data.length

        XCTAssertEqual(try destination(in: input, from: headerEnd, direction: .right), following.location)
        XCTAssertEqual(try destination(in: input, from: following.location, direction: .left), headerEnd)
        XCTAssertTrue(input.lineManager.isLineHidden(3))
    }

    func testSelectionDelegateCanReplaceDocumentDuringCollapseCaretRelocation() throws {
        let (view, input) = try makeTextView()
        view.selectedRange = NSRange(location: (source as NSString).range(of: "work").location, length: 0)
        let delegate = FoldingSelectionReplacementDelegate()
        view.editorDelegate = delegate

        input.toggleFold(atRow: 1, animated: false)
        input.refreshCodeFolding(synchronously: true)
        settle(view, input: input)

        XCTAssertTrue(delegate.didReplaceDocument, "The collapse must exercise the selection callback before applying its old range.")
        XCTAssertEqual(view.text, "x")
        XCTAssertEqual(input.lineManager.lineCount, 1)
        XCTAssertTrue(input.lineManager.foldedLineProjection.spans.isEmpty)
        XCTAssertTrue(input.foldingController.rangesByRow.isEmpty)
        XCTAssertLessThanOrEqual(NSMaxRange(view.selectedRange), 1)
    }

    func testRevealingSearchDestinationExpandsItsContainingFold() throws {
        let (view, input) = try makeTextView()
        let match = (source as NSString).range(of: "work")
        input.toggleFold(atRow: 1, animated: false)
        XCTAssertTrue(input.lineManager.isLineHidden(3))

        // Search navigation uses this public destination-reveal path.
        view.scrollRangeToVisible(match)
        settle(view, input: input)

        XCTAssertFalse(input.lineManager.isLineHidden(3))
        let caret = input.convert(input.caretRect(at: match.location), to: view)
        XCTAssertGreaterThanOrEqual(caret.minY, view.bounds.minY - 0.5)
        XCTAssertLessThanOrEqual(caret.maxY, view.bounds.maxY + 0.5)
    }

    func testSelectionAcrossFoldRetainsCompleteSourceForCopy() throws {
        let (view, input) = try makeTextView()
        input.toggleFold(atRow: 1, animated: false)
        let start = input.lineManager.line(atRow: 1).location
        let end = input.lineManager.line(atRow: 6).location
        let selection = NSRange(location: start, length: end - start)
        let expected = (source as NSString).substring(with: selection)
        view.selectedRange = selection
        let selectedTextRange = try XCTUnwrap(input.selectedTextRange)

        XCTAssertEqual(view.selectedRange, selection)
        XCTAssertEqual(input.text(in: selection), expected)
        // Copy obtains its source through this UITextInput contract. The app-less
        // XCTest runner cannot access the system pasteboard; host-app checks cover that write.
        XCTAssertEqual(input.text(in: selectedTextRange), expected)
        XCTAssertTrue(expected.contains("work();"))
        XCTAssertTrue(input.lineManager.isLineHidden(3), "Copying a range with visible endpoints must retain the fold.")
    }

    func testEditingBeforeFoldTranslatesCollapsedStateAndUndoRestoresSource() throws {
        let (view, input) = try makeTextView()
        input.toggleFold(atRow: 1, animated: false)
        // The future caret falls inside the old collapsed body until the edit
        // updates the line tree. It must not accidentally reveal that old range.
        let prefix = "// added first line\n// added second line\n// added third line\n"

        input.replace(IndexedRange(location: 0, length: 0), withText: prefix)
        input.refreshCodeFolding(synchronously: true)
        settle(view, input: input)

        XCTAssertEqual(view.text, prefix + source)
        XCTAssertEqual(input.selectedRange, NSRange(location: prefix.utf16.count, length: 0))
        XCTAssertTrue(input.lineManager.isLineHidden(6))
        XCTAssertFalse(input.lineManager.isLineHidden(4))
        XCTAssertTrue(input.foldingController.collapsedRanges.contains { $0.startRow == 4 })
        let undo = try XCTUnwrap(input.undoManager)
        XCTAssertTrue(undo.canUndo)
        undo.undo()
        input.refreshCodeFolding(synchronously: true)
        settle(view, input: input)
        XCTAssertEqual(view.text, source)
    }

    func testGutterDisclosureWorksWithoutLineNumbersAndDisablingRestoresText() throws {
        let (view, input) = try makeTextView(showLineNumbers: false)
        let expandedHeight = input.lineManager.contentHeight
        let button = try XCTUnwrap(foldingButtons(in: input.gutterContainerView).first { button in
            button.accessibilityIdentifier == "Runestone.Fold.1"
        })
        XCTAssertGreaterThan(input.gutterContainerView.bounds.width, 0)
        XCTAssertNotNil(button.toggle)
        let action = try XCTUnwrap(button.actions(forTarget: button, forControlEvent: .touchUpInside)?.first,
                                   "A reused disclosure must retain its control event target.")
        let selector = NSSelectorFromString(action)
        XCTAssertTrue(button.responds(to: selector))
        let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY),
                                    to: input.gutterContainerView)
        XCTAssertEqual(input.gutterContainerView.hitTest(center, with: nil), button)

        var activationCount = 0
        let toggle = button.toggle
        button.toggle = {
            activationCount += 1
            toggle?()
        }
        // App-less XCTest has no UIApplication to dispatch control events. Invoke
        // the registered target action; the host Example verifies actual gutter taps.
        _ = button.perform(selector)
        settle(view, input: input)
        XCTAssertEqual(activationCount, 1, "One control action must toggle the fold exactly once.")
        XCTAssertTrue(input.lineManager.isLineHidden(3))

        view.isCodeFoldingEnabled = false
        settle(view, input: input)
        XCTAssertTrue(input.lineManager.foldedLineProjection.spans.isEmpty)
        XCTAssertTrue(foldingButtons(in: input.gutterContainerView).isEmpty)
        XCTAssertEqual(input.lineManager.contentHeight, expandedHeight, accuracy: 0.5)
        XCTAssertEqual(view.text, source)
    }

    func testLargeCollapsedRangeSkipsHiddenControllersDuringLayoutAndLookup() throws {
        let text = "{\n" + String(repeating: "x\n", count: 10_000) + "}\nafter"
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let last = lineManager.lastLine
        let hidden = lineManager.line(atRow: 5_000)
        let estimatedHeight = hidden.data.lineHeight
        lineManager.setCollapsedLineRanges([1...(last.index - 1)])
        let configuration = InvisibleCharacterConfiguration()
        let highlights = HighlightService(lineManager: lineManager)
        let factory = LineControllerFactory(stringView: stringView, highlightService: highlights,
                                            invisibleCharacterConfiguration: configuration)
        let storage = LineControllerStorage(stringView: stringView, lineControllerFactory: factory)
        let gutterWidth = GutterWidthService(lineManager: lineManager)
        let contentSize = ContentSizeService(lineManager: lineManager, lineControllerStorage: storage,
                                             gutterWidthService: gutterWidth, invisibleCharacterConfiguration: configuration)
        let caretRects = CaretRectService(stringView: stringView, lineManager: lineManager,
                                          lineControllerStorage: storage, gutterWidthService: gutterWidth)
        let selectionRects = SelectionRectService(lineManager: lineManager, contentSizeService: contentSize,
                                                  gutterWidthService: gutterWidth, caretRectService: caretRects)
        let layout = LayoutManager(lineManager: lineManager, languageMode: PlainTextInternalLanguageMode(),
                                   stringView: stringView, lineControllerStorage: storage, contentSizeService: contentSize,
                                   gutterWidthService: gutterWidth, caretRectService: caretRects,
                                   selectionRectService: selectionRects, highlightService: highlights,
                                   invisibleCharacterConfiguration: configuration)
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        layout.textInputView = parent
        layout.scrollViewWidth = parent.bounds.width
        layout.viewport = parent.bounds
        contentSize.scrollViewWidth = parent.bounds.width
        layout.setNeedsLayout()
        layout.layoutIfNeeded()

        XCTAssertNil(storage[hidden.id], "Collapsed text must not allocate a line controller during viewport layout.")
        XCTAssertEqual(hidden.data.lineHeight, estimatedHeight, "Collapsed text must keep its lazy height estimate.")
        XCTAssertEqual(lineManager.nextVisibleLine(after: lineManager.firstLine)?.id, last.id)
        XCTAssertEqual(lineManager.line(containingYOffset: last.yPosition)?.id, last.id)
        XCTAssertEqual(lineManager.line(containingYOffset: lineManager.contentHeight)?.id, last.id)
        XCTAssertEqual(Set(storage.map { $0.line.index }), Set([0, last.index]),
                       "Only the two displayed logical lines should need controllers.")
        XCTAssertEqual(layout.visibleTextRanges.count, 2)
    }

    private func makeTextView(enabled: Bool = true, showLineNumbers: Bool = true,
                              text: String? = nil) throws -> (TextView, TextInputView) {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 360, height: 260))
        view.contentInsetAdjustmentBehavior = .never
        view.isAutomaticScrollEnabled = false
        view.isLineWrappingEnabled = false
        view.showLineNumbers = showLineNumbers
        let host = UIWindow(frame: view.frame)
        let controller = UIViewController()
        host.rootViewController = controller
        controller.view.addSubview(view)
        host.isHidden = false
        window = host
        let language = TreeSitterLanguage(tree_sitter_javascript(), foldsQuery: .init(string: "(statement_block) @fold"))
        view.setState(TextViewState(text: text ?? source, language: language))
        view.isCodeFoldingEnabled = enabled
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        input.refreshCodeFolding(synchronously: true)
        settle(view, input: input)
        return (view, input)
    }

    private func settle(_ view: TextView, input: TextInputView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
    }

    private func foldingButtons(in view: UIView) -> [FoldingGutterButton] {
        view.subviews.flatMap { child in
            if let button = child as? FoldingGutterButton {
                return [button]
            }
            return foldingButtons(in: child)
        }
    }

    private func destination(in input: TextInputView, from location: Int,
                             direction: UITextLayoutDirection) throws -> Int {
        try XCTUnwrap(input.position(from: IndexedPosition(index: location), in: direction, offset: 1) as? IndexedPosition).index
    }
}

private final class FoldingSelectionReplacementDelegate: TextViewDelegate {
    private(set) var didReplaceDocument = false

    func textViewDidChangeSelection(_ textView: TextView) {
        guard !didReplaceDocument else {
            return
        }
        didReplaceDocument = true
        textView.setState(TextViewState(text: "x"))
    }
}
