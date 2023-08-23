#if os(iOS)
import Combine
import UIKit

struct StandardCaretColorUpdater {
    private let textSelectionViewProvider: UITextSelectionViewProvider
    private var textSelectionView: UIView? {
        textSelectionViewProvider.textSelectionView
    }

    init(textSelectionViewProvider: UITextSelectionViewProvider) {
        self.textSelectionViewProvider = textSelectionViewProvider
    }

    func updateStandardCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        guard let textSelectionView else {
            return
        }
        let parentView = textSelectionView.superview
        textSelectionView.removeFromSuperview()
        parentView?.addSubview(textSelectionView)
    }
}
#endif
