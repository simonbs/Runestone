import Foundation

public extension TextViewDelegate {
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool {
        true
    }

    func textViewShouldEndEditing(_ textView: TextView) -> Bool {
        true
    }

    func textViewDidBeginEditing(_ textView: TextView) {}

    func textViewDidEndEditing(_ textView: TextView) {}

    func textViewDidChange(_ textView: TextView) {}

    func textViewDidChangeSelection(_ textView: TextView) {}

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        true
    }

    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool {
        true
    }

    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool {
        true
    }

    func textViewDidChangeGutterWidth(_ textView: TextView) {}

    func textViewDidBeginFloatingCursor(_ textView: TextView) {}

    func textViewDidEndFloatingCursor(_ textView: TextView) {}

    func textViewDidLoopToLastHighlightedRange(_ textView: TextView) {}

    func textViewDidLoopToFirstHighlightedRange(_ textView: TextView) {}

    func textView(_ textView: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        false
    }

    func textView(_ textView: TextView, replaceTextIn highlightedRange: HighlightedRange) {}
}
