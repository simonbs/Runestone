#if os(iOS)
import Combine
import UIKit

final class TextInputDelegate_iOS: TextInputDelegate {
    private let textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private var inputDelegate: UITextInputDelegate? {
        textView.value.value?.inputDelegate
    }

    init(textView: CurrentValueSubject<WeakBox<TextView>, Never>) {
        self.textView = textView
    }

    func selectionWillChange() {
        if let textView = textView.value.value {
            inputDelegate?.selectionWillChange(textView)
        }
    }

    func selectionDidChange() {
        selectionDidChange(sendAnonymously: false)
    }

    func selectionDidChange(sendAnonymously: Bool) {
        guard let textView = textView.value.value else {
            return
        }
        if sendAnonymously {
            inputDelegate?.selectionDidChange(nil)
        } else {
            inputDelegate?.selectionDidChange(textView)
        }
    }
}
#endif
