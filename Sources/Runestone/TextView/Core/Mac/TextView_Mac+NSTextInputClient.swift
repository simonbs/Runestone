#if os(macOS)
import AppKit

extension TextView: NSTextInputClient {
    public override func doCommand(by selector: Selector) {
        #if DEBUG
        print(NSStringFromSelector(selector))
        #endif
        super.doCommand(by: selector)
    }

    public func insertText(_ string: Any, replacementRange: NSRange) {
        guard let string = string as? String else {
            return
        }
        if replacementRange.location == NSNotFound {
            textViewController.replaceText(in: textViewController.rangeForInsertingText, with: string)
        } else {
            textViewController.replaceText(in: replacementRange, with: string)
        }
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {}

    public func unmarkText() {}

    public func selectedRange() -> NSRange {
        textViewController.selectedRange ?? NSRange(location: 0, length: 0)
    }

    public func markedRange() -> NSRange {
        textViewController.markedRange ?? NSRange(location: 0, length: 0)
    }

    public func hasMarkedText() -> Bool {
        (textViewController.markedRange?.length ?? 0) > 0
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        .zero
    }

    public func characterIndex(for point: NSPoint) -> Int {
        0
    }
}
#endif
