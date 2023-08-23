#if os(iOS)
import Combine
import UIKit

final class StandardFloatingCaretHider {
    private let caretParentViewProvider: StandardCaretParentViewProvider
    private let floatingCaretViewProvider: StandardFloatingCaretViewProvider
    private var subviewsObserver: NSKeyValueObservation?
    private var floatingCaretViewHiddenObserver: NSKeyValueObservation?
    private var caretParentView: UIView? {
        caretParentViewProvider.parentView
    }
    private var floatingCaretView: UIView? {
        floatingCaretViewProvider.floatingCaretView
    }

    init(
        caretParentViewProvider: StandardCaretParentViewProvider,
        floatingCaretViewProvider: StandardFloatingCaretViewProvider
    ) {
        self.caretParentViewProvider = caretParentViewProvider
        self.floatingCaretViewProvider = floatingCaretViewProvider
    }

    func setupFloatingCaretViewObserver() {
        subviewsObserver = caretParentView?.observe(\.layer.sublayers, options: .new) { [weak self] _, change in
            DispatchQueue.main.async { [weak self] in
                self?.hideStandardFloatingCaretView()
            }
        }
    }
}

private extension StandardFloatingCaretHider {
    private func hideStandardFloatingCaretView() {
        floatingCaretView?.isHidden = true
        floatingCaretViewHiddenObserver = floatingCaretView?.observe(\.isHidden) { [weak self] _, _ in
            if let floatingCaretView = self?.floatingCaretView, !floatingCaretView.isHidden {
                floatingCaretView.isHidden = true
            }
        }
    }
}
#endif
