#if os(iOS)
import Combine
import UIKit

final class StandardFloatingCaretHider {
    private var subviewsObserver: NSKeyValueObservation?
    private var floatingCaretViewHiddenObserver: NSKeyValueObservation?
    private var caretParentView: UIView? {
        if #available(iOS 17, *) {
            view
        } else {
            view?.runestone_textSelectionView
        }
    }
    private var floatingCaretView: UIView? {
        view?.runestone_floatingCaretView
    }

    private weak var view: UIView?

    init(view: UIView) {
        self.view = view
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
