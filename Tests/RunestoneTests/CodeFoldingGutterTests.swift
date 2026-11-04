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

    func testFoldingFeedbackCanBeDisabledWithoutDisablingAnimatedFolds() async throws {
        let (view, input) = try makeTextView()
        let collapseFeedback = FoldingFeedbackSpy(style: .rigid)
        let expandFeedback = FoldingFeedbackSpy(style: .soft)
        input.collapseFeedback = collapseFeedback
        input.expandFeedback = expandFeedback
        XCTAssertTrue(view.isCodeFoldingHapticFeedbackEnabled)

        for feedbackEnabled in [true, false, true] {
            view.isCodeFoldingHapticFeedbackEnabled = feedbackEnabled
            let previousCollapseCount = collapseFeedback.intensities.count
            let previousExpandCount = expandFeedback.intensities.count
            for isCollapsing in [true, false] {
                let button = try XCTUnwrap(foldingButtons(in: input.gutterContainerView).first { button in
                    button.accessibilityIdentifier == "Runestone.Fold.1"
                })
                let action = try XCTUnwrap(button.actions(forTarget: button, forControlEvent: .touchUpInside)?.first)
                _ = button.perform(NSSelectorFromString(action))
                XCTAssertEqual(input.lineManager.isLineHidden(3), isCollapsing)
                try await Task.sleep(nanoseconds: 400_000_000)
                settle(view, input: input)
            }
            XCTAssertEqual(collapseFeedback.intensities.count, previousCollapseCount + (feedbackEnabled ? 1 : 0))
            XCTAssertEqual(expandFeedback.intensities.count, previousExpandCount + (feedbackEnabled ? 1 : 0))
            XCTAssertEqual(view.text, source)
        }
        XCTAssertEqual(collapseFeedback.intensities, [0.5, 0.5])
        XCTAssertEqual(expandFeedback.intensities, [0.5, 0.5])
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

    func testFindDimmingCoversGutterAndPreservesFoldingHitTargets() throws {
        let (view, input) = try makeTextView()
        let gutter = input.gutterContainerView
        view.contentInset.top = 80
        view.contentOffset = CGPoint(x: 40, y: -80)
        settle(view, input: input)
        let sample = CGPoint(x: 2, y: -40)
        let normalBrightness = try gutterBrightness(gutter, at: sample)

        // Requesting find alone must preserve the opt-in contract.
        view.isFindResultPresentationActive = true
        XCTAssertEqual(try gutterBrightness(gutter, at: sample), normalBrightness)
        view.isFindResultPresentationEnabled = true
        settle(view, input: input)
        XCTAssertLessThan(try gutterBrightness(gutter, at: sample), normalBrightness - 30)

        for showLineNumbers in [true, false, true] {
            view.showLineNumbers = showLineNumbers
            // Rebuild folding controls while find remains active.
            view.isCodeFoldingEnabled = false
            view.isCodeFoldingEnabled = true
            input.refreshCodeFolding(synchronously: true)
            view.contentOffset = CGPoint(x: showLineNumbers ? 80 : 40, y: -80)
            settle(view, input: input)
            let button = try XCTUnwrap(foldingButtons(in: gutter).first)
            assertGutterEdgesHit(button, in: gutter)
            let dim = try XCTUnwrap(gutter.layer.sublayers?.last)
            XCTAssertEqual(dim.backgroundColor, FindResultPresentationView.dimmingColor.cgColor)
            XCTAssertFalse(dim.isHidden)
            XCTAssertEqual(dim.frame, CGRect(x: 0, y: input.viewport.minY,
                                             width: gutter.bounds.width, height: input.viewport.height))
            XCTAssertTrue(gutter.subviews.allSatisfy { child in
                guard let layers = gutter.layer.sublayers,
                      let childIndex = layers.firstIndex(of: child.layer),
                      let dimIndex = layers.firstIndex(of: dim) else { return false }
                return childIndex < dimIndex
            }, "Dimming must cover line numbers and newly created folding controls")
        }

        view.isFindResultPresentationEnabled = false
        settle(view, input: input)
        XCTAssertEqual(try gutterBrightness(gutter, at: sample), normalBrightness)
        view.isFindResultPresentationEnabled = true
        view.isFindResultPresentationActive = false
        settle(view, input: input)
        XCTAssertEqual(try gutterBrightness(gutter, at: sample), normalBrightness)
    }

    private func gutterBrightness(_ gutter: UIView, at point: CGPoint) throws -> Int {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            context.cgContext.translateBy(x: -point.x, y: -point.y)
            gutter.layer.render(in: context.cgContext)
        }
        let data = try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        return Int(bytes[0]) + Int(bytes[1]) + Int(bytes[2])
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

private final class FoldingFeedbackSpy: UIImpactFeedbackGenerator {
    private(set) var intensities: [CGFloat] = []

    override func impactOccurred(intensity: CGFloat) {
        intensities.append(intensity)
    }
}
