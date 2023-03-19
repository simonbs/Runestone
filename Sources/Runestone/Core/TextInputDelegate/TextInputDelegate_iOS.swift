#if os(iOS)
import UIKit

final class TextInputDelegate_iOS: TextInputDelegate {
    weak var inputDelegate: UITextInputDelegate?

    private unowned let textView: TextView

    func selectionWillChange() {
        inputDelegate?.selectionWillChange(textView)
    }

    func selectionDidChange() {
        selectionDidChange(sendAnonymously: false)
    }

    func selectionDidChange(sendAnonymously: Bool) {
        if sendAnonymously {
            inputDelegate?.selectionDidChange(nil)
        } else {
            inputDelegate?.selectionDidChange(textView)
        }
    }
}
#endif
