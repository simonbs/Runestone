#if canImport(AppKit)
import AppKit

/// A small set of commands for a prepared input session. This is not a complete
/// AppKit command dispatcher: unsupported selectors and commands during marked
/// text are left to the caller. Left/right currently use logical text order,
/// not visual bidirectional layout order.
enum PreparedInputCommandInterpreter {
    /// nil means the command was not handled. A non-nil result must be observed
    /// by the connection so that a rejected event triggers its normal reset;
    /// a rejected edit must never be retried as a second document mutation.
    static func perform(_ selector: Selector, adapter: PreparedInputEventAdapter,
                        view: ReadOnlyDocumentView) -> PreparedInputEventAdapter.Outcome? {
        precondition(Thread.isMainThread)
        let name = NSStringFromSelector(selector)
        guard ["insertTab:", "deleteBackward:", "deleteForward:",
               "moveLeft:", "moveRight:"].contains(name) else { return nil }

        let selection = adapter.selectedRangeForInput()
        guard selection.location != NSNotFound else {
            return adapter.needsInputReset ? .resetRequired : .unavailable
        }
        guard let provisional = adapter.hasProvisionalCompositionForInput() else {
            return adapter.needsInputReset ? .resetRequired : .unavailable
        }
        guard !provisional else { return nil }
        guard !view.isRetired else { return .unavailable }
        let text = view.content.string as NSString
        guard selection.location >= 0, selection.length >= 0,
              selection.location <= text.length,
              selection.length <= text.length - selection.location else { return .resetRequired }
        let end = selection.location + selection.length
        // Input methods may place the caret at a scalar boundary inside one
        // grapheme. Deleting the whole cluster there would erase characters
        // on the opposite side of the caret that were never selected.
        if selection.length == 0, (name == "deleteBackward:" || name == "deleteForward:"),
           selection.location > 0, selection.location < text.length,
           text.rangeOfComposedCharacterSequence(at: selection.location).location < selection.location {
            return nil
        }
        switch name {
        case "insertTab:":
            return adapter.insertText("\t", replacementRange: selection)
        case "deleteBackward:":
            if selection.length > 0 { return adapter.insertText("", replacementRange: selection) }
            guard selection.location > 0 else { return .processed }
            let cluster = text.rangeOfComposedCharacterSequence(at: selection.location - 1)
            return adapter.insertText("", replacementRange: cluster)
        case "deleteForward:":
            if selection.length > 0 { return adapter.insertText("", replacementRange: selection) }
            guard selection.location < text.length else { return .processed }
            let cluster = text.rangeOfComposedCharacterSequence(at: selection.location)
            return adapter.insertText("", replacementRange: cluster)
        case "moveLeft:":
            let location: Int
            if selection.length > 0 { location = selection.location }
            else if selection.location > 0 { location = text.rangeOfComposedCharacterSequence(at: selection.location - 1).location }
            else { return .processed }
            return adapter.setSelection(NSRange(location: location, length: 0))
        case "moveRight:":
            let location: Int
            if selection.length > 0 { location = end }
            else if end < text.length { location = NSMaxRange(text.rangeOfComposedCharacterSequence(at: end)) }
            else { return .processed }
            return adapter.setSelection(NSRange(location: location, length: 0))
        default:
            return nil
        }
    }
}
#endif
