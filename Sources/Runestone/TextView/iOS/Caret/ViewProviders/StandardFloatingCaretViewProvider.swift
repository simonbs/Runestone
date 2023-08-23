#if os(iOS)
import Combine
import UIKit

struct StandardFloatingCaretViewProvider {
    var floatingCaretView: UIView? {
        if #available(iOS 17, *) {
            return floatingCaretView_postiOS17
        } else {
            return floatingCaretView_preiOS17
        }
    }

    // swiftlint:disable:next type_name
    @available(iOS 17, *)
    private var floatingCaretView_postiOS17: UIView? {
        guard let klass = NSClassFromString("_UITextCursorView") else {
            return nil
        }
        let cursorViews = textView?.subviews.filter { $0.isKind(of: klass) } ?? []
        guard cursorViews.count >= 2 else {
            return nil
        }
        return cursorViews.last
    }

    // swiftlint:disable:next type_name
    private var floatingCaretView_preiOS17: UIView? {
        textSelectionView?.value(forKey: "m_floatingCaretView") as? UIView
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
