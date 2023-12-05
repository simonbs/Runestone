#if os(iOS)
import Combine
import UIKit

struct UITextSelectionViewProvider {
    var textSelectionView: UIView? {
        if #unavailable(iOS 17), let klass = NSClassFromString("UITextSelectionView") {
            return view?.subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }

    private weak var view: UIView?

    init(view: UIView) {
        self.view = view
    }
}
#endif
