#if os(iOS)
import Combine
import UIKit

struct StandardCaretViewProvider {
    var caretView: UIView? {
        if #available(iOS 17, *), let klass = NSClassFromString("_UITextCursorView") {
            return view?.subviews.first { $0.isKind(of: klass) }
        } else {
            return textSelectionViewProvider.textSelectionView?.value(forKey: "m_caretView") as? UIView
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
