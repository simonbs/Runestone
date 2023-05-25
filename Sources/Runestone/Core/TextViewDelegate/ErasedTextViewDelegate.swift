import Combine
import Foundation

final class ErasedTextViewDelegate {
    weak var delegate: TextViewDelegate?

    private let _textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private var textView: TextView {
        _textView.value.value!
    }

    init(textView: CurrentValueSubject<WeakBox<TextView>, Never>) {
        _textView = textView
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

    func textViewDidChangeSelection() {
        delegate?.textViewDidChangeSelection(textView)
    }

    func textViewDidBeginFloatingCursor() {
        delegate?.textViewDidBeginFloatingCursor(textView)
    }

    func textViewDidEndFloatingCursor() {
        delegate?.textViewDidEndFloatingCursor(textView)
    }
}
