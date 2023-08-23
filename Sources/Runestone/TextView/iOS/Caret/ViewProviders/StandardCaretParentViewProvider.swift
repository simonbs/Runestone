#if os(iOS)
import Combine
import UIKit

struct StandardCaretParentViewProvider {
    var parentView: UIView? {
        if #available(iOS 17, *) {
            textView
        } else {
            textSelectionView
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
