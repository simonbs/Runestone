#if os(macOS)
import AppKit

final class TextInputClientView: NSView, NSTextInputClient {
    override var acceptsFirstResponder: Bool {
        return true
    }

    override func doCommand(by selector: Selector) {
        print(selector)
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        print(string)
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {

    }

    func unmarkText() {

    }

    func selectedRange() -> NSRange {
        NSRange(location: 0, length: 0)
    }

    func markedRange() -> NSRange {
        NSRange(location: 0, length: 0)
    }

    func hasMarkedText() -> Bool {
        false
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        .zero
    }

    func characterIndex(for point: NSPoint) -> Int {
        0
    }
}

#endif
