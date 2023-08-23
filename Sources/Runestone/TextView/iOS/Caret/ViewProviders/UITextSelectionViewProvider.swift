#if os(iOS)
import Combine
import UIKit

struct UITextSelectionViewProvider {
    var textSelectionView: UIView? {
        if #unavailable(iOS 17), let klass = NSClassFromString("UITextSelectionView") {
            return textView?.subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }

    private let _textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private var textView: TextView? {
        _textView.value.value
    }

    init(textView: CurrentValueSubject<WeakBox<TextView>, Never>) {
        _textView = textView
    }
}
#endif
