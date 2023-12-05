#if os(iOS)
import Combine
import UIKit

struct StandardCaretParentViewProvider {
    var parentView: UIView? {
        if #available(iOS 17, *) {
            view
        } else {
            textSelectionViewProvider.textSelectionView
        }
    }

    private weak var view: UIView?
    private let textSelectionViewProvider: UITextSelectionViewProvider

    init(view: UIView, textSelectionViewProvider: UITextSelectionViewProvider) {
        self.view = view
        self.textSelectionViewProvider = textSelectionViewProvider
    }
}
#endif
