#if os(iOS)
import Combine
import UIKit

struct StandardCaretViewProvider {
    var caretView: UIView? {
        if #available(iOS 17, *), let klass = NSClassFromString("_UITextCursorView") {
            return textView?.subviews.first { $0.isKind(of: klass) }
        } else {
            return textSelectionView?.value(forKey: "m_caretView") as? UIView
        }
    }

    private let _textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private let textSelectionViewProvider: UITextSelectionViewProvider
    private var textView: TextView? {
        _textView.value.value
    }
    private var textSelectionView: UIView? {
        textSelectionViewProvider.textSelectionView
    }

    init(
        textView: CurrentValueSubject<WeakBox<TextView>, Never>,
        textSelectionViewProvider: UITextSelectionViewProvider
    ) {
        self._textView = textView
        self.textSelectionViewProvider = textSelectionViewProvider
    }
}
#endif
