@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

@MainActor
final class CodeFoldingGutterTests: XCTestCase {
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

    func testGutterDisclosureCoversLineWithAndWithoutNumbersAndDisablingRestoresText() throws {
        for showLineNumbers in [false, true] {
            let (view, input) = try makeTextView(showLineNumbers: showLineNumbers)
            let expandedHeight = input.lineManager.contentHeight
            let gutter = input.gutterContainerView
            let button = try XCTUnwrap(foldingButtons(in: gutter).first { button in
                button.accessibilityIdentifier == "Runestone.Fold.1"
            })
            let header = input.lineManager.line(atRow: 1)
            let nextLine = input.lineManager.line(atRow: 2)
            XCTAssertGreaterThan(gutter.bounds.width, 0)
            XCTAssertEqual(button.frame.minX, gutter.bounds.minX, accuracy: 0.01)
            XCTAssertEqual(button.frame.maxX, gutter.bounds.maxX, accuracy: 0.01)
            XCTAssertEqual(button.frame.height, header.data.lineHeight, accuracy: 0.01)
            XCTAssertEqual(button.frame.maxY, view.textContainerInset.top + nextLine.yPosition, accuracy: 0.01,
                           "A small line's disclosure must not extend into the next line")
            assertGutterEdgesHit(button, in: gutter)
            let ordinaryLine = input.lineManager.firstLine
            let ordinaryPoint = CGPoint(x: gutter.bounds.midX,
                                        y: view.textContainerInset.top + ordinaryLine.data.lineHeight / 2)
            XCTAssertNil(gutter.hitTest(ordinaryPoint, with: nil), "Nonfoldable gutter rows must allow scrolling")
            let action = try XCTUnwrap(button.actions(forTarget: button, forControlEvent: .touchUpInside)?.first,
                                       "A reused disclosure must retain its control event target.")

            // App-less XCTest has no UIApplication to dispatch control events. Invoke
            // the registered target action; the host Example verifies actual gutter taps.
            _ = button.perform(NSSelectorFromString(action))
            settle(view, input: input)
            XCTAssertTrue(input.lineManager.isLineHidden(3))

            view.isCodeFoldingEnabled = false
            settle(view, input: input)
            XCTAssertTrue(input.lineManager.foldedLineProjection.spans.isEmpty)
            XCTAssertTrue(foldingButtons(in: gutter).isEmpty)
            XCTAssertEqual(input.lineManager.contentHeight, expandedHeight, accuracy: 0.5)
            XCTAssertEqual(view.text, source)
        }
    }

    func testWrappedHeaderDisclosureCoversFullLogicalLineAtIncreasedLineHeight() throws {
        let longName = String(repeating: "longFunctionName", count: 6)
        let text = "function \(longName)() {\n  work();\n}\nafter"
        for showLineNumbers in [false, true] {
            let (view, input) = try makeTextView(showLineNumbers: showLineNumbers, text: text)
            view.isLineWrappingEnabled = true
            view.lineHeightMultiplier = 1.8
            input.layoutLines(toLocation: text.utf16.count)
            settle(view, input: input)
            let gutter = input.gutterContainerView
            let button = try XCTUnwrap(foldingButtons(in: gutter).first { button in
                button.accessibilityIdentifier == "Runestone.Fold.0"
            })
            let header = input.lineManager.firstLine
            let firstFragmentHeight = view.theme.font.totalLineHeight * view.lineHeightMultiplier
            XCTAssertGreaterThan(header.data.lineHeight, firstFragmentHeight * 1.5, "The header must wrap for this case")
            XCTAssertEqual(button.frame.height, header.data.lineHeight, accuracy: 0.01)
            assertGutterEdgesHit(button, in: gutter)
            let action = try XCTUnwrap(button.actions(forTarget: button, forControlEvent: .touchUpInside)?.first)
            _ = button.perform(NSSelectorFromString(action))
            settle(view, input: input)
            XCTAssertTrue(input.lineManager.isLineHidden(1))
            XCTAssertEqual(view.text, text)
        }
    }

    private func assertGutterEdgesHit(_ button: FoldingGutterButton, in gutter: UIView,
                                      file: StaticString = #filePath, line: UInt = #line) {
        for x in [gutter.bounds.minX + 0.5, gutter.bounds.maxX - 0.5] {
            for y in [button.frame.minY + 0.5, button.frame.maxY - 0.5] {
                XCTAssertEqual(gutter.hitTest(CGPoint(x: x, y: y), with: nil), button,
                               "Every corner of the line's gutter must activate its disclosure", file: file, line: line)
            }
        }
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

}
