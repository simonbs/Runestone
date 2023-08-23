#if os(iOS)
import Combine
import UIKit

final class StandardCaretHider {
    private let caretParentViewProvider: StandardCaretParentViewProvider
    private let caretViewProvider: StandardCaretViewProvider
    private var subviewsObserver: NSKeyValueObservation?
    private var caretViewHiddenObserver: NSKeyValueObservation?
    private var caretParentView: UIView? {
        caretParentViewProvider.parentView
    }
    private var caretView: UIView? {
        caretViewProvider.caretView
    }

    init(
        caretParentViewProvider: StandardCaretParentViewProvider,
        caretViewProvider: StandardCaretViewProvider
    ) {
        self.caretParentViewProvider = caretParentViewProvider
        self.caretViewProvider = caretViewProvider
    }

    func setupCaretViewObserver() {
        subviewsObserver = caretParentView?.observe(\.layer.sublayers, options: .new) { [weak self] _, change in
            DispatchQueue.main.async { [weak self] in
                self?.hideStandardCaretView()
            }
        }
    }
}

private extension StandardCaretHider {
    private func hideStandardCaretView() {
        caretView?.isHidden = true
        caretViewHiddenObserver = caretView?.observe(\.isHidden) { [weak self] _, _ in
            if let caretView = self?.caretView, !caretView.isHidden {
                caretView.isHidden = true
            }
        }
    }
}
#endif
