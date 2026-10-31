#if canImport(AppKit)
import AppKit
import ObjectiveC

/// Internal command dispatch. Left/right use logical text order; visual-line
/// movement is handled separately by the responder's Core Text geometry.
enum PreparedInputCommandInterpreter {
    enum Result: Equatable {
        case unsupported
        case blocked(PreparedInputEventAdapter.InputFailure)
        case handled(PreparedInputEventAdapter.InputAttempt)
    }

    enum Direction { case backward, forward }

    private final class SelectionAnchor: NSObject {
        let anchor: Int
        let extent: Int
        let selection: NSRange
        let contentRevision: UUID
        let selectionRevision: UUID

        init(anchor: Int, extent: Int, selection: NSRange, view: ReadOnlyDocumentView) {
            self.anchor = anchor
            self.extent = extent
            self.selection = selection
            self.contentRevision = view.contentRevision
            self.selectionRevision = view.inputSelectionRevision
        }

        func matches(_ range: NSRange, view: ReadOnlyDocumentView) -> Bool {
            selection == range && contentRevision == view.contentRevision && selectionRevision == view.inputSelectionRevision
        }
    }

    private static var selectionAnchorKey: UInt8 = 0

    /// The endpoint to move. A recorded active endpoint is reused only while
    /// the exact selection, content, and selection revision still match. Viewport
    /// or layout changes do not by themselves invalidate the logical anchor.
    static func movementOrigin(selection: NSRange, extending: Bool, direction: Direction,
                               view: ReadOnlyDocumentView) -> Int {
        if extending, let state = anchorState(for: selection, view: view) { return state.extent }
        return direction == .backward ? selection.location : NSMaxRange(selection)
    }

    /// Apply a logical or geometry-provided target through the same document
    /// reservation. Geometry users can share the extension anchor with commands.
    static func moveSelection(target: Int, selection: NSRange, extending: Bool, direction: Direction,
                              adapter: PreparedInputEventAdapter, view: ReadOnlyDocumentView,
                              isAvailable: () -> Bool = { true }) -> Result {
        let text = view.manager.stringView.string
        guard validSelection(selection, in: text), isGraphemeBoundary(target, in: text) else {
            return .blocked(.init(reason: .invalidSelection, effect: .notApplied))
        }
        let anchor: Int
        if extending {
            anchor = anchorState(for: selection, view: view)?.anchor ??
                (direction == .backward ? NSMaxRange(selection) : selection.location)
        } else {
            anchor = target
        }
        let start = min(anchor, target)
        let range = NSRange(location: start, length: max(anchor, target) - start)
        let attempt = adapter.setSelectionReporting(range, isAvailable: isAvailable)
        if attempt.outcome == .processed {
            if extending {
                objc_setAssociatedObject(view, &selectionAnchorKey,
                    SelectionAnchor(anchor: anchor, extent: target, selection: range, view: view), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                clearAnchor(view)
            }
        }
        return .handled(attempt)
    }

    private static func anchorState(for selection: NSRange, view: ReadOnlyDocumentView) -> SelectionAnchor? {
        guard let state = objc_getAssociatedObject(view, &selectionAnchorKey) as? SelectionAnchor,
              state.matches(selection, view: view) else { return nil }
        return state
    }

    /// Preserve the fixed endpoint when Shift-click extends an existing
    /// keyboard selection. A stale anchor is never returned.
    static func selectionAnchor(for selection: NSRange, in view: ReadOnlyDocumentView) -> Int? {
        anchorState(for: selection, view: view)?.anchor
    }

    static func isValidSelectionRange(_ selection: NSRange, in text: NSString) -> Bool {
        validSelection(selection, in: text)
    }

    static func isValidBoundary(_ offset: Int, in text: NSString) -> Bool { isGraphemeBoundary(offset, in: text) }

    /// External pointer, clipboard or focus operations discard the previous
    /// keyboard anchor even when they leave an identical selected range.
    static func resetSelectionExtension(in view: ReadOnlyDocumentView) { clearAnchor(view) }

    private static func clearAnchor(_ view: ReadOnlyDocumentView) {
        objc_setAssociatedObject(view, &selectionAnchorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func perform(_ selector: Selector, adapter: PreparedInputEventAdapter,
                        view: ReadOnlyDocumentView) -> PreparedInputEventAdapter.Outcome? {
        switch performReporting(selector, adapter: adapter, view: view) {
        case .unsupported, .blocked: return nil
        case let .handled(attempt): return attempt.outcome
        }
    }

    private static let supportedCommands: Set<String> = [
        "insertTab:", "insertNewline:", "insertLineBreak:", "deleteBackward:", "deleteForward:",
        "deleteWordBackward:", "deleteWordForward:", "selectAll:",
        "moveLeft:", "moveRight:", "moveBackward:", "moveForward:",
        "moveLeftAndModifySelection:", "moveRightAndModifySelection:",
        "moveBackwardAndModifySelection:", "moveForwardAndModifySelection:",
        "moveWordLeft:", "moveWordRight:", "moveWordBackward:", "moveWordForward:",
        "moveWordLeftAndModifySelection:", "moveWordRightAndModifySelection:",
        "moveWordBackwardAndModifySelection:", "moveWordForwardAndModifySelection:",
        "moveToBeginningOfDocument:", "moveToEndOfDocument:",
        "moveToBeginningOfDocumentAndModifySelection:", "moveToEndOfDocumentAndModifySelection:",
        "moveToBeginningOfParagraph:", "moveToEndOfParagraph:",
        "moveToBeginningOfParagraphAndModifySelection:", "moveToEndOfParagraphAndModifySelection:"
    ]
    static func supports(_ name: String) -> Bool { supportedCommands.contains(name) }

    static func performReporting(_ selector: Selector, adapter: PreparedInputEventAdapter,
                                 view: ReadOnlyDocumentView, isAvailable: () -> Bool = { true }) -> Result {
        precondition(Thread.isMainThread)
        let name = NSStringFromSelector(selector)
        guard supports(name) else { return .unsupported }

        func failure(_ reason: PreparedInputEventAdapter.InputFailure.Reason,
                     outcome: PreparedInputEventAdapter.Outcome = .unavailable) -> Result {
            .handled(.init(outcome: outcome, failure: .init(reason: reason, effect: .notApplied)))
        }
        func success() -> Result { .handled(.init(outcome: .processed, failure: nil)) }
        func finish(_ attempt: PreparedInputEventAdapter.InputAttempt) -> Result {
            if attempt.outcome == .processed { clearAnchor(view) }
            return .handled(attempt)
        }
        let selection = adapter.selectedRangeForInput()
        guard selection.location != NSNotFound else {
            return failure(.unavailable, outcome: adapter.needsInputReset ? .resetRequired : .unavailable)
        }
        guard let provisional = adapter.hasProvisionalCompositionForInput() else {
            return failure(.unavailable, outcome: adapter.needsInputReset ? .resetRequired : .unavailable)
        }
        guard !provisional else { return .blocked(.init(reason: .compositionActive, effect: .notApplied)) }
        guard !view.isRetired else { return failure(.unavailable) }
        let text = view.manager.stringView.string
        guard validSelection(selection, in: text) else {
            return .blocked(.init(reason: .invalidSelection, effect: .notApplied))
        }

        switch name {
        case "insertTab:": return finish(adapter.insertTextReporting("\t", replacementRange: selection, isAvailable: isAvailable))
        case "insertNewline:": return finish(adapter.insertLogicalNewlineReporting(isAvailable: isAvailable))
        case "insertLineBreak:": return finish(adapter.insertLogicalLineBreakReporting(isAvailable: isAvailable))
        case "selectAll:": return finish(adapter.setSelectionReporting(NSRange(location: 0, length: text.length), isAvailable: isAvailable))
        case "deleteBackward:", "deleteForward:", "deleteWordBackward:", "deleteWordForward:":
            if selection.length > 0 { return finish(adapter.insertTextReporting("", replacementRange: selection, isAvailable: isAvailable)) }
            let backward = name == "deleteBackward:" || name == "deleteWordBackward:"
            let word = name == "deleteWordBackward:" || name == "deleteWordForward:"
            let origin = selection.location
            let target: Int
            if word { target = backward ? wordBoundaryBackward(from: origin, in: text) : wordBoundaryForward(from: origin, in: text) }
            else if backward && origin > 0 { target = previousBoundary(before: origin, in: text) }
            else if !backward && origin < text.length { target = nextBoundary(after: origin, in: text) }
            else { return success() }
            guard target != origin else { return success() }
            guard isGraphemeBoundary(target, in: text) else {
                return .blocked(.init(reason: .invalidSelection, effect: .notApplied))
            }
            return finish(adapter.insertTextReporting("", replacementRange: NSRange(location: min(origin, target), length: abs(target - origin)), isAvailable: isAvailable))
        default:
            break
        }

        let extending = name.contains("AndModifySelection:")
        let backward = name.contains("Left") || name.contains("Backward") || name.contains("Beginning")
        let direction: Direction = backward ? .backward : .forward
        let origin = movementOrigin(selection: selection, extending: extending, direction: direction, view: view)
        let target: Int
        if name.contains("Document") {
            target = backward ? 0 : text.length
        } else if name.contains("Paragraph") {
            target = paragraphBoundary(in: text, at: origin, beginning: backward)
        } else if !extending && selection.length > 0 {
            // An unmodified horizontal move collapses a selection first.
            target = backward ? selection.location : NSMaxRange(selection)
        } else if name.contains("Word") {
            target = backward ? wordBoundaryBackward(from: origin, in: text) : wordBoundaryForward(from: origin, in: text)
        } else if backward && origin > 0 {
            target = previousBoundary(before: origin, in: text)
        } else if !backward && origin < text.length {
            target = nextBoundary(after: origin, in: text)
        } else {
            target = origin
        }
        return moveSelection(target: target, selection: selection, extending: extending, direction: direction,
                             adapter: adapter, view: view, isAvailable: isAvailable)
    }

    private static func validSelection(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return false }
        return isGraphemeBoundary(range.location, in: text) && isGraphemeBoundary(NSMaxRange(range), in: text)
    }

    private static func isGraphemeBoundary(_ offset: Int, in text: NSString) -> Bool {
        guard offset >= 0, offset <= text.length else { return false }
        guard offset > 0 && offset < text.length else { return true }
        // Foundation does not consistently treat CRLF as a single composed
        // sequence. No movement or deletion may target its interior.
        guard !(text.character(at: offset - 1) == 0x0D && text.character(at: offset) == 0x0A) else { return false }
        return text.rangeOfComposedCharacterSequence(at: offset).location == offset
    }

    private static func previousBoundary(before offset: Int, in text: NSString) -> Int {
        if offset >= 2, text.character(at: offset - 2) == 0x0D, text.character(at: offset - 1) == 0x0A {
            return offset - 2
        }
        return text.rangeOfComposedCharacterSequence(at: offset - 1).location
    }

    private static func nextBoundary(after offset: Int, in text: NSString) -> Int {
        if offset + 1 < text.length, text.character(at: offset) == 0x0D, text.character(at: offset + 1) == 0x0A {
            return offset + 2
        }
        return NSMaxRange(text.rangeOfComposedCharacterSequence(at: offset))
    }

    private static func paragraphBoundary(in text: NSString, at offset: Int, beginning: Bool) -> Int {
        var start = 0, end = 0, contentsEnd = 0
        text.getParagraphStart(&start, end: &end, contentsEnd: &contentsEnd,
                               for: NSRange(location: offset, length: 0))
        return beginning ? start : contentsEnd
    }

    /// Foundation word ranges handle scripts and combining marks. An emoji or
    /// other symbol in the intervening gap remains an independently reachable
    /// grapheme instead of being silently skipped with punctuation/whitespace.
    private static func wordBoundaryBackward(from offset: Int, in text: NSString) -> Int {
        guard offset > 0 else { return 0 }
        var word: NSRange?
        text.enumerateSubstrings(in: NSRange(location: 0, length: offset),
                                 options: [.byWords, .reverse, .substringNotRequired]) { _, range, _, stop in
            word = range
            stop.pointee = true
        }
        let limit = word.map(NSMaxRange) ?? 0
        var position = offset
        while position > limit {
            let cluster = text.rangeOfComposedCharacterSequence(at: position - 1)
            if isSymbol(cluster, in: text) { return cluster.location }
            position = cluster.location
        }
        return word?.location ?? 0
    }

    private static func wordBoundaryForward(from offset: Int, in text: NSString) -> Int {
        guard offset < text.length else { return text.length }
        var word: NSRange?
        text.enumerateSubstrings(in: NSRange(location: offset, length: text.length - offset),
                                 options: [.byWords, .substringNotRequired]) { _, range, _, stop in
            word = range
            stop.pointee = true
        }
        let limit = word?.location ?? text.length
        var position = offset
        while position < limit {
            let cluster = text.rangeOfComposedCharacterSequence(at: position)
            if isSymbol(cluster, in: text) { return NSMaxRange(cluster) }
            position = NSMaxRange(cluster)
        }
        return word.map(NSMaxRange) ?? text.length
    }

    private static func isSymbol(_ range: NSRange, in text: NSString) -> Bool {
        (text.substring(with: range) as NSString).rangeOfCharacter(from: .symbols).location != NSNotFound
    }
}
#endif
