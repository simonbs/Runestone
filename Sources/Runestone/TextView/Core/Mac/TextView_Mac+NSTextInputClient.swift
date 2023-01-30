#if os(macOS)
import AppKit

extension TextView: NSTextInputClient {
    public override func doCommand(by selector: Selector) {
        if selector == NSSelectorFromString("deleteBackward:") {
            deleteBackward()
        } else if selector == NSSelectorFromString("insertNewline:") {
            textViewController.indentController.insertLineBreak(in: textViewController.rangeForInsertingText, using: lineEndings)
        } else {
            #if DEBUG
            print(NSStringFromSelector(selector))
            #endif
            super.doCommand(by: selector)
        }
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

private extension TextView {
    private func deleteBackward() {
        guard var selectedRange = textViewController.markedRange ?? textViewController.selectedRange else {
            return
        }
        if selectedRange.length == 0 {
            selectedRange.location -= 1
            selectedRange.length = 1
        }
        let deleteRange = textViewController.rangeForDeletingText(in: selectedRange)
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == textViewController.markedRange {
            textViewController.markedRange = nil
        }
        guard textViewController.shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
            undoManager?.beginUndoGrouping()
        }
        textViewController.replaceText(in: deleteRange, with: "", selectedRangeAfterUndo: selectedRange)
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
        }
    }
}
#endif
