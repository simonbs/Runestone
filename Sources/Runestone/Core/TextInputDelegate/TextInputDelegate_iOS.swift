#if os(iOS)
import Combine
import UIKit

final class TextInputDelegate_iOS: TextInputDelegate {
//    private let proxyTextView: ProxyTextView
//    private var inputDelegate: UITextInputDelegate? {
//        proxyTextView.textView?.inputDelegate
//    }

    func selectionWillChange() {
//        if let textView = proxyTextView.textView {
//            inputDelegate?.selectionWillChange(textView)
//        }
    }

    func selectionDidChange() {
//        selectionDidChange(sendAnonymously: false)
    }

    func selectionDidChange(sendAnonymously: Bool) {
//        guard let textView = proxyTextView.textView else {
//            return
//        }
//        if sendAnonymously {
//            inputDelegate?.selectionDidChange(nil)
//        } else {
//            inputDelegate?.selectionDidChange(textView)
//        }
    }
}
#endif
