#if os(macOS)
import AppKit

extension TextView: NSTextInputClient {
    // swiftlint:disable:next prohibited_super_call
    override public func doCommand(by selector: Selector) {
//        #if DEBUG
//        print(NSStringFromSelector(selector))
//        #endif
        super.doCommand(by: selector)
    }

    public func insertText(_ string: Any, replacementRange: NSRange) {
        guard let string = string as? String else {
            return
        }
        let range = replacementRange.location == NSNotFound ? textViewController.rangeForInsertingText : replacementRange
        if textViewController.shouldChangeText(in: range, replacementText: string) {
            textViewController.replaceText(in: range, with: string)
        }
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {}

    public func unmarkText() {}

    public func selectedRange() -> NSRange {
        textViewController.selectedRange?.nonNegativeLength ?? NSRange(location: 0, length: 0)
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
