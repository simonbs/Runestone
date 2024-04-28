#if os(iOS)
import Combine
import UIKit

final class StandardCaretHider {
    private var subviewsObserver: NSKeyValueObservation?
    private var caretViewHiddenObserver: NSKeyValueObservation?
    private var caretParentView: UIView? {
        if #available(iOS 17, *) {
            view
        } else {
            view?.runestone_textSelectionView
        }
    }
    private var caretView: UIView? {
        view?.runestone_caretView
    }

    private weak var view: UIView?

    init(view: UIView) {
        self.view = view
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
