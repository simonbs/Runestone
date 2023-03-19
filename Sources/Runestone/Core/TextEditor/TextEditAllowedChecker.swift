import Foundation

final class TextEditAllowedChecker {
    private unowned let textView: TextView
    private let textViewDelegateBox: TextViewDelegateBox

    init(textView: TextView, textViewDelegateBox: TextViewDelegateBox) {
        self.textView = textView
        self.textViewDelegateBox = textViewDelegateBox
    }

    func shouldChangeText(in range: NSRange, replacementText: String) -> Bool {
        guard let delegate = textViewDelegateBox.delegate else {
            return true
        }
        return delegate.textView(textView, shouldChangeTextIn: range, replacementText: replacementText)
    }
}
