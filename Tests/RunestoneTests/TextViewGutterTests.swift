@testable import Runestone
import UIKit
import XCTest

@MainActor
final class TextViewGutterTests: XCTestCase {
    func testLineNumbersAreExcludedFromAccessibilityWithoutHidingTextOrOverlayControls() throws {
        let textView = try makeTextView()
        let textInputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView } as? TextInputView)
        let overlayButton = UIButton(type: .system)
        overlayButton.setTitle("Editor action", for: .normal)
        textView.addSubview(overlayButton)

        let labels = descendants(of: textInputView.gutterContainerView).compactMap { $0 as? UILabel }
        XCTAssertFalse(labels.isEmpty, "The test must exercise rendered line numbers.")
        for label in labels {
            XCTAssertTrue(isExcludedFromAccessibility(label), "Decorative line numbers must not become separate VoiceOver stops.")
        }
        XCTAssertFalse(isExcludedFromAccessibility(textInputView), "The editable text must remain available to assistive technology.")
        XCTAssertFalse(isExcludedFromAccessibility(overlayButton), "Hiding line numbers must not hide editor controls.")
    }

    func testLayoutKeepsGutterBelowOverlayAndAboveText() throws {
        let textView = try makeTextView()
        let textInputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView } as? TextInputView)
        let gutter = textInputView.gutterContainerView
        let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        overlay.frame = CGRect(x: 0, y: 0, width: textView.bounds.width, height: 80)
        textView.addSubview(overlay)

        for showLineNumbers in [true, false, true] {
            textView.showLineNumbers = showLineNumbers
            textView.setNeedsLayout()
            textView.layoutIfNeeded()

            let textIndex = try XCTUnwrap(textView.subviews.firstIndex(of: textInputView))
            let gutterIndex = try XCTUnwrap(textView.subviews.firstIndex(of: gutter))
            let overlayIndex = try XCTUnwrap(textView.subviews.firstIndex(of: overlay))
            XCTAssertGreaterThan(gutterIndex, textIndex, "The gutter must cover the text and its selection views.")
            XCTAssertLessThan(gutterIndex, overlayIndex, "A scroll view overlay must cover the gutter as well as the text.")
        }
    }

    func testGutterStaysPinnedWhileTextScrollsHorizontally() throws {
        let textView = try makeTextView()
        let textInputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView } as? TextInputView)
        let gutter = textInputView.gutterContainerView
        XCTAssertGreaterThan(textView.contentSize.width, textView.bounds.width + 160)
        XCTAssertGreaterThan(gutter.bounds.width, 0)

        for horizontalOffset in [CGFloat(80), 160, 0] {
            textView.contentOffset = CGPoint(x: horizontalOffset, y: 0)
            textView.setNeedsLayout()
            textView.layoutIfNeeded()

            XCTAssertEqual(gutter.frame.minX - textView.bounds.minX, 0, accuracy: 0.5)
            XCTAssertEqual(textInputView.frame.minX - textView.bounds.minX, -horizontalOffset, accuracy: 0.5)
        }
    }

    private func makeTextView() throws -> TextView {
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        textView.contentInsetAdjustmentBehavior = .never
        textView.isLineWrappingEnabled = false
        textView.showLineNumbers = true
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        textView.text = String(repeating: "long line ", count: 100) + "\nsecond line"
        let textInputView = try XCTUnwrap(textView.subviews.first { $0 is TextInputView } as? TextInputView)
        // Explicitly typeset the content because this view is not attached to a window.
        textInputView.layoutLines(toLocation: textInputView.string.length)
        textInputView.setNeedsLayout()
        textInputView.layoutIfNeeded()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        return textView
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private func isExcludedFromAccessibility(_ view: UIView) -> Bool {
        var ancestor: UIView? = view
        while let current = ancestor {
            if current.accessibilityElementsHidden { return true }
            ancestor = current.superview
        }
        return false
    }
}
