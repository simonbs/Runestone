import Foundation

final class ErasedTextViewDelegate {
    weak var delegate: TextViewDelegate?

    private unowned let textView: TextView

    init(textView: TextView) {
        self.textView = textView
    }

    func textViewDidChange() {
        delegate?.textViewDidChange(textView)
    }

    func textViewDidEndEditing() {
        delegate?.textViewDidEndEditing(textView)
    }

    func textViewDidLoopToLastHighlightedRange() {
        delegate?.textViewDidLoopToLastHighlightedRange(textView)
    }

    func textViewDidLoopToFirstHighlightedRange() {
        delegate?.textViewDidLoopToFirstHighlightedRange(textView)
    }

    func shouldInsert(_ characterPair: CharacterPair, in range: NSRange) -> Bool {
        delegate?.textView(textView, shouldInsert: characterPair, in: range) ?? true
    }

    func shouldSkipTrailingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        delegate?.textView(textView, shouldSkipTrailingComponentOf: characterPair, in: range) ?? true
    }

    func shouldChangeText(in range: NSRange, replacementText: String) -> Bool {
        delegate?.textView(textView, shouldChangeTextIn: range, replacementText: replacementText) ?? true
    }
}
