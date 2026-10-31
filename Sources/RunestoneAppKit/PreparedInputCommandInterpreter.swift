#if canImport(AppKit)
import AppKit

/// A limited internal command dispatcher. It distinguishes selectors which the
/// responder may forward from recognized commands which are unsafe to perform.
/// Left/right use logical text order, not visual bidirectional layout order.
enum PreparedInputCommandInterpreter {
    enum Result: Equatable {
        case unsupported
        case blocked(PreparedInputEventAdapter.InputFailure)
        case handled(PreparedInputEventAdapter.InputAttempt)
    }

    /// Legacy convenience used by existing callers; nil includes both unsupported
    /// and blocked commands. New responders must use performReporting to distinguish them.
    static func perform(_ selector: Selector, adapter: PreparedInputEventAdapter,
                        view: ReadOnlyDocumentView) -> PreparedInputEventAdapter.Outcome? {
        switch performReporting(selector, adapter: adapter, view: view) {
        case .unsupported, .blocked: return nil
        case let .handled(attempt): return attempt.outcome
        }
    }

    static func performReporting(_ selector: Selector, adapter: PreparedInputEventAdapter,
                                 view: ReadOnlyDocumentView) -> Result {
        precondition(Thread.isMainThread)
        let name = NSStringFromSelector(selector)
        guard ["insertTab:", "insertNewline:", "insertLineBreak:", "deleteBackward:", "deleteForward:",
               "moveLeft:", "moveRight:"].contains(name) else { return .unsupported }

        func failure(_ reason: PreparedInputEventAdapter.InputFailure.Reason,
                     outcome: PreparedInputEventAdapter.Outcome = .unavailable) -> Result {
            .handled(.init(outcome: outcome, failure: .init(reason: reason, effect: .notApplied)))
        }
        func success() -> Result { .handled(.init(outcome: .processed, failure: nil)) }
        let selection = adapter.selectedRangeForInput()
        guard selection.location != NSNotFound else {
            return failure(.unavailable, outcome: adapter.needsInputReset ? .resetRequired : .unavailable)
        }
        guard let provisional = adapter.hasProvisionalCompositionForInput() else {
            return failure(.unavailable, outcome: adapter.needsInputReset ? .resetRequired : .unavailable)
        }
        guard !provisional else { return .blocked(.init(reason: .compositionActive, effect: .notApplied)) }
        guard !view.isRetired else { return failure(.unavailable) }
        let text = view.content.string as NSString
        guard selection.location >= 0, selection.length >= 0,
              selection.location <= text.length,
              selection.length <= text.length - selection.location else {
            return failure(.invalidSelection, outcome: .resetRequired)
        }
        let end = selection.location + selection.length
        // Never delete unselected text on the opposite side of a caret inside
        // one composed grapheme; this is a recognized but blocked command.
        if selection.length == 0, (name == "deleteBackward:" || name == "deleteForward:"),
           selection.location > 0, selection.location < text.length,
           text.rangeOfComposedCharacterSequence(at: selection.location).location < selection.location {
            return .blocked(.init(reason: .invalidSelection, effect: .notApplied))
        }
        switch name {
        case "insertTab:":
            return .handled(adapter.insertTextReporting("\t", replacementRange: selection))
        case "insertNewline:":
            return .handled(adapter.insertLogicalNewlineReporting())
        case "insertLineBreak:":
            return .handled(adapter.insertLogicalLineBreakReporting())
        case "deleteBackward:":
            if selection.length > 0 { return .handled(adapter.insertTextReporting("", replacementRange: selection)) }
            guard selection.location > 0 else { return success() }
            let cluster = text.rangeOfComposedCharacterSequence(at: selection.location - 1)
            return .handled(adapter.insertTextReporting("", replacementRange: cluster))
        case "deleteForward:":
            if selection.length > 0 { return .handled(adapter.insertTextReporting("", replacementRange: selection)) }
            guard selection.location < text.length else { return success() }
            let cluster = text.rangeOfComposedCharacterSequence(at: selection.location)
            return .handled(adapter.insertTextReporting("", replacementRange: cluster))
        case "moveLeft:":
            let location: Int
            if selection.length > 0 { location = selection.location }
            else if selection.location > 0 { location = text.rangeOfComposedCharacterSequence(at: selection.location - 1).location }
            else { return success() }
            return .handled(adapter.setSelectionReporting(NSRange(location: location, length: 0)))
        case "moveRight:":
            let location: Int
            if selection.length > 0 { location = end }
            else if end < text.length { location = NSMaxRange(text.rangeOfComposedCharacterSequence(at: end)) }
            else { return success() }
            return .handled(adapter.setSelectionReporting(NSRange(location: location, length: 0)))
        default:
            return .unsupported
        }
    }
}
#endif
