import Foundation

final class CharacterPairHandlingAllowedChecker {
    private unowned let textView: TextView
    private let textViewDelegateBox: TextViewDelegateBox

    init(textView: TextView, textViewDelegateBox: TextViewDelegateBox) {
        self.textView = textView
        self.textViewDelegateBox = textViewDelegateBox
    }

    func shouldInsert(_ characterPair: CharacterPair, in range: NSRange) -> Bool {
        guard let delegate = textViewDelegateBox.delegate else {
            return true
        }
        return delegate.textView(textView, shouldInsert: characterPair, in: range)
    }

    func shouldSkipTrailingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        guard let delegate = textViewDelegateBox.delegate else {
            return true
        }
        return delegate.textView(textView, shouldSkipTrailingComponentOf: characterPair, in: range)
    }
}
