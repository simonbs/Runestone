#if canImport(AppKit)
import AppKit

/// Clipboard work for a prepared input view. The caller must hold its outer
/// dispatch reservation and apply each failure to the connection's reporting.
/// The pasteboard is injected so tests never touch a user's clipboard.
enum PreparedInputClipboardCommand {
    enum Operation: Equatable { case copy, cut, paste }

    protocol Pasteboard {
        /// A metadata-only type check used for menu validation.
        var hasPlainText: Bool { get }
        func readPlainText() -> String?
        /// May have changed the pasteboard even when it returns false.
        func writePlainText(_ value: String) -> Bool
    }

    struct SystemPasteboard: Pasteboard {
        let board: NSPasteboard
        var hasPlainText: Bool { board.availableType(from: [.string]) != nil }
        func readPlainText() -> String? { board.string(forType: .string) }
        func writePlainText(_ value: String) -> Bool {
            board.clearContents()
            return board.setString(value, forType: .string)
        }
    }

    enum Result: Equatable {
        case processed
        /// A failure concerns this action only. Clipboard writes and input
        /// callouts can already have had effects; never replay the operation.
        case failed(PreparedInputEventAdapter.InputFailure, needsReset: Bool)
    }

    private struct Snapshot {
        let selection: NSRange
        let documentRevision: UUID
        let contentRevision: UUID
        let geometryRevision: UUID
    }

    /// Menu validation is advisory. Perform repeats all checks after admission.
    static func canPerform(_ operation: Operation, adapter: PreparedInputEventAdapter,
                           view: ReadOnlyDocumentView, pasteboard: Pasteboard) -> Bool {
        precondition(Thread.isMainThread)
        guard case let .valid(snapshot) = snapshot(adapter: adapter, view: view) else { return false }
        switch operation {
        case .copy, .cut: return snapshot.selection.length > 0
        case .paste:
            let available = pasteboard.hasPlainText
            return available && isCurrent(snapshot, adapter: adapter, view: view)
        }
    }

    /// Run only within a document dispatch lease. The snapshot and selection
    /// are revalidated after every pasteboard callout. Input is never normalized.
    static func perform(_ operation: Operation, adapter: PreparedInputEventAdapter,
                        view: ReadOnlyDocumentView, pasteboard: Pasteboard,
                        isAvailable: () -> Bool = { true }) -> Result {
        precondition(Thread.isMainThread)
        guard isAvailable() else { return failure(.unavailable, .notApplied, adapter: adapter) }
        let initial: Snapshot
        switch snapshot(adapter: adapter, view: view) {
        case let .valid(value): initial = value
        case let .invalid(reason): return failure(reason, .notApplied, adapter: adapter)
        }
        switch operation {
        case .copy, .cut:
            guard initial.selection.length > 0 else { return failure(.invalidSelection, .notApplied, adapter: adapter) }
            var actual = NSRange(location: NSNotFound, length: 0)
            guard let value = adapter.attributedSubstringForInput(range: initial.selection, actualRange: &actual)?.string,
                  actual == initial.selection, isAvailable(), isCurrent(initial, adapter: adapter, view: view), isAvailable() else {
                return failure(.unavailable, .notApplied, adapter: adapter)
            }
            // The clipboard is written first: a failed clipboard write must
            // never delete the document selection. Even a reported failure can
            // have cleared or changed the system pasteboard.
            let wrote = pasteboard.writePlainText(value)
            guard wrote, isAvailable(), isCurrent(initial, adapter: adapter, view: view), isAvailable() else {
                return failure(.unavailable, .mayHaveApplied, adapter: adapter)
            }
            guard operation == .cut else { return .processed }
            return edit(adapter.insertTextReporting("", replacementRange: initial.selection, isAvailable: isAvailable),
                        afterPasteboardCallout: true)
        case .paste:
            guard let value = pasteboard.readPlainText() else {
                return failure(.unavailable, .mayHaveApplied, adapter: adapter)
            }
            guard isAvailable(), isCurrent(initial, adapter: adapter, view: view), isAvailable() else {
                return failure(.unavailable, .mayHaveApplied, adapter: adapter)
            }
            return edit(adapter.insertTextReporting(value, replacementRange: initial.selection, isAvailable: isAvailable),
                        afterPasteboardCallout: true)
        }
    }

    private enum Capture {
        case valid(Snapshot)
        case invalid(PreparedInputEventAdapter.InputFailure.Reason)
    }

    private static func snapshot(adapter: PreparedInputEventAdapter, view: ReadOnlyDocumentView) -> Capture {
        guard !view.isRetired, adapter.ownsInputView(view),
              let state = adapter.inputStateForHost() else { return .invalid(.unavailable) }
        guard !state.hasComposition else { return .invalid(.compositionActive) }
        guard let revision = adapter.installedRevisionForDispatch else { return .invalid(.unavailable) }
        let contentRevision = view.contentRevision
        let geometryRevision = view.inputGeometryRevision
        let text = view.manager.stringView.string
        let range = state.selection
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location,
              isGraphemeBoundary(range.location, in: text),
              isGraphemeBoundary(range.location + range.length, in: text) else { return .invalid(.invalidSelection) }
        let result = Snapshot(selection: range, documentRevision: revision, contentRevision: contentRevision,
                              geometryRevision: geometryRevision)
        return isCurrent(result, adapter: adapter, view: view) ? .valid(result) : .invalid(.unavailable)
    }

    private static func isGraphemeBoundary(_ index: Int, in text: NSString) -> Bool {
        guard index > 0 && index < text.length else { return true }
        if text.character(at: index - 1) == 0x0D && text.character(at: index) == 0x0A { return false }
        return text.rangeOfComposedCharacterSequence(at: index).location == index
    }

    private static func isCurrent(_ snapshot: Snapshot, adapter: PreparedInputEventAdapter,
                                  view: ReadOnlyDocumentView) -> Bool {
        guard !view.isRetired, view.contentRevision == snapshot.contentRevision,
              view.inputGeometryRevision == snapshot.geometryRevision,
              adapter.installedRevisionForDispatch == snapshot.documentRevision,
              let state = adapter.inputStateForHost(), !state.hasComposition,
              state.selection == snapshot.selection else { return false }
        return !view.isRetired && view.contentRevision == snapshot.contentRevision &&
            view.inputGeometryRevision == snapshot.geometryRevision &&
            adapter.installedRevisionForDispatch == snapshot.documentRevision
    }

    private static func edit(_ attempt: PreparedInputEventAdapter.InputAttempt,
                             afterPasteboardCallout: Bool) -> Result {
        guard let issue = attempt.failure else { return .processed }
        let effect: PreparedInputEventAdapter.InputFailure.Effect = afterPasteboardCallout ? .mayHaveApplied : issue.effect
        return .failed(.init(reason: issue.reason, effect: effect), needsReset: attempt.outcome != .processed)
    }

    private static func failure(_ reason: PreparedInputEventAdapter.InputFailure.Reason,
                                _ effect: PreparedInputEventAdapter.InputFailure.Effect,
                                adapter: PreparedInputEventAdapter) -> Result {
        .failed(.init(reason: reason, effect: effect), needsReset: adapter.needsInputReset)
    }
}
#endif
