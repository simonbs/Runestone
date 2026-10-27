@testable import Runestone
import UIKit
import XCTest

#if compiler(>=5.9)
@available(iOS 17, *)
@MainActor
final class CaretAppearanceTests: XCTestCase {
    func testCaretAppearsAtFullSizeWhenFocusChangesInsideAnAnimation() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let controller = UIViewController()
        window.rootViewController = controller
        let textView = TextView(frame: window.bounds)
        textView.text = "Hello, caret"
        controller.view.addSubview(textView)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let input = try XCTUnwrap(textView.subviews.compactMap { $0 as? TextInputView }.first)
        defer {
            _ = input.resignFirstResponder()
            window.isHidden = true
        }

        // A keyboard or containing view transition must not animate a newly installed
        // caret from its initial size. Re-enabling editing installs the interaction again.
        for reenablingEditing in [false, true] {
            if reenablingEditing {
                textView.isEditable = false
                textView.isEditable = true
            }
            textView.selectedRange = NSRange(location: 5, length: 0)
            UIView.animate(withDuration: 1) {
                XCTAssertTrue(input.becomeFirstResponder())
                textView.layoutIfNeeded()
                input.layoutIfNeeded()
            }
            CATransaction.flush()

            let interaction = try XCTUnwrap(input.sbs_textSelectionDisplayInteraction)
            let caret = interaction.cursorView
            XCTAssertFalse(caret.isHidden)
            XCTAssertGreaterThan(caret.alpha, 0)
            XCTAssertFalse(caret.bounds.isEmpty)
            XCTAssertNotNil(caret.window)
            XCTAssertTrue(sizeAnimationKeyPaths(in: caret.layer).isEmpty,
                          "The caret should appear at full size, without bounds or transform animations: \(sizeAnimationKeyPaths(in: caret.layer))")
        }
    }

    private func sizeAnimationKeyPaths(in layer: CALayer) -> [String] {
        let ownAnimations = (layer.animationKeys() ?? []).compactMap { layer.animation(forKey: $0) }
        return ownAnimations.flatMap(sizeAnimationKeyPaths(in:))
            + (layer.sublayers ?? []).flatMap(sizeAnimationKeyPaths(in:))
    }

    private func sizeAnimationKeyPaths(in animation: CAAnimation) -> [String] {
        if let group = animation as? CAAnimationGroup {
            return (group.animations ?? []).flatMap(sizeAnimationKeyPaths(in:))
        }
        guard let keyPath = (animation as? CAPropertyAnimation)?.keyPath,
              keyPath == "bounds" || keyPath.hasPrefix("bounds.size")
                || keyPath == "transform" || keyPath.hasPrefix("transform.scale") else {
            return []
        }
        return [keyPath]
    }
}
#endif
