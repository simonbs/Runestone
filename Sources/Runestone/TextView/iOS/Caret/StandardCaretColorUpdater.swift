#if os(iOS)
import Combine
import UIKit

struct StandardCaretColorUpdater {
    private weak var view: UIView?

    init(view: UIView) {
        self.view = view
    }

    func updateStandardCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        guard let textSelectionView = view?.runestone_textSelectionView else {
            return
        }
        let parentView = textSelectionView.superview
        textSelectionView.removeFromSuperview()
        parentView?.addSubview(textSelectionView)
    }
}
#endif
