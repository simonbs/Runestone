#if os(iOS)
import UIKit

extension UIView {
    var runestone_textSelectionView: UIView? {
        guard let klass = NSClassFromString("UITextSelectionView") else {
            return nil
        }
        return subviews.first { $0.isKind(of: klass) }
    }

    @available(iOS 17, *)
    var runestone_textCursorView: UIView? {
        guard let klass = NSClassFromString("_UITextCursorView") else {
            return nil
        }
        return subviews.first { $0.isKind(of: klass) }
    }

    var runestone_caretView: UIView? {
        if #available(iOS 17, *) {
            return runestone_textCursorView
        } else {
            return runestone_textSelectionView?.value(forKey: "m_caretView") as? UIView
        }
    }

    var runestone_floatingCaretView: UIView? {
        guard #available(iOS 17, *) else {
            return runestone_textSelectionView?.value(forKey: "m_floatingCaretView") as? UIView
        }
        guard let klass = NSClassFromString("_UITextCursorView") else {
            return nil
        }
        let cursorViews = subviews.filter { $0.isKind(of: klass) }
        guard cursorViews.count >= 2 else {
            return nil
        }
        return cursorViews.last
    }
}
#endif
