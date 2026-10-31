#if canImport(AppKit)
import AppKit

/// Internal state for future AppKit text input. The session exclusively owns
/// content changes to its view; callers must not mutate the view independently.
/// It does not implement NSTextInputClient, undo, selection drawing, or input
/// method geometry and must not be exposed as an interactive editor on its own.
///
/// `contentDidChange` is synchronous and receives a copied attributed snapshot
/// after a successful text or attribute mutation and after state is updated.
/// Attribute values are not deep-copied. Replacing a range with identical
/// attributed content and changing only selection or marked state do not notify.
/// Reentrant session operations are rejected until the callback returns. A
/// external content update makes the session reject operations until refresh.
/// As with the underlying view, attribute values must be treated as immutable.
final class DocumentInputSession {
    /// A prepared change owns a reservation of the canonical document state.
    /// `publish` must only install already validated canonical state. It must
    /// not fail, call out, notify observers, or enter an event loop. `finish`
    /// performs undo registration, synchronization and notifications after the
    /// view has laid out; it must not mutate this session or its view directly.
    struct PreparedChange {
        let publish: () -> Void
        let finish: () -> Void
    }

    /// Prepares a complete candidate without changing observable state.
    /// nil rejects the edit; returned closures must retain any reservation until
    /// consumed or discarded. The owner must serialize document transactions.
    typealias PrepareChange = (NSAttributedString) -> PreparedChange?

    private let view: ReadOnlyDocumentView
    private let mutationPermit: ReadOnlyDocumentView.InputMutationPermit?
    private let prepareChange: PrepareChange?
    private let mutationAuthority: ReadOnlyDocumentView.InputMutationAuthority?
    private var expectedRevision: UUID
    private var isApplyingChange = false

    private var storedSelection = NSRange(location: 0, length: 0)
    private var storedMarkedRange: NSRange?
    /// A stale session reports an unavailable selection and no marked range.
    var selectedRange: NSRange { contentMatches ? storedSelection : NSRange(location: NSNotFound, length: 0) }
    var markedRange: NSRange? { contentMatches ? storedMarkedRange : nil }
    var isStale: Bool { !contentMatches }
    var contentDidChange: ((NSAttributedString) -> Void)?

    init(view: ReadOnlyDocumentView, mutationPermit: ReadOnlyDocumentView.InputMutationPermit? = nil,
         prepareChange: PrepareChange? = nil) {
        self.view = view
        self.mutationPermit = mutationPermit
        self.prepareChange = prepareChange
        // Atomic publication is only valid with exclusive view ownership.
        self.mutationAuthority = (prepareChange == nil || mutationPermit != nil) ? view.bindInputSession(to: mutationPermit) : nil
        self.expectedRevision = view.contentRevision
    }

    /// Silently replaces the document and clears selection and composition.
    /// Call this to adopt a new document or recover after outside mutation.
    /// Prepared sessions reject refresh until document-driven synchronization is available.
    @discardableResult
    func refresh(content: NSAttributedString) -> Bool {
        guard prepareChange == nil, let authority = mutationAuthority, !isApplyingChange,
              let transaction = view.beginInputMutation(with: mutationPermit, authority: authority) else { return false }
        isApplyingChange = true
        defer {
            isApplyingChange = false
            view.endInputMutation(transaction)
        }
        guard view.setContentReturningRevision(content, permit: mutationPermit, transaction: transaction, didCommit: { revision in
            expectedRevision = revision
            storedSelection = NSRange(location: 0, length: 0)
            storedMarkedRange = nil
        }) != nil else { return false }
        return contentMatches
    }

    /// Sets a document-relative UTF-16 selection, rejecting invalid ranges.
    @discardableResult
    func setSelection(_ range: NSRange) -> Bool {
        guard isCurrent, isValid(range, in: view.manager.stringView.string) else { return false }
        if storedSelection != range {
            storedSelection = range
            view.noteInputCoordinatesChanged()
        }
        return true
    }

    /// Inserts plain text using caller-supplied attributes. NSNotFound chooses
    /// the marked range when present, otherwise the current selection.
    @discardableResult
    func insertText(_ text: String, replacementRange: NSRange,
                    attributes: [NSAttributedString.Key: Any]) -> Bool {
        insertText(NSAttributedString(string: text, attributes: attributes), replacementRange: replacementRange)
    }

    /// Preserves the supplied attributed runs in an accepted insertion.
    @discardableResult
    func insertText(_ content: NSAttributedString, replacementRange: NSRange) -> Bool {
        guard isCurrent else { return false }
        let range = resolvedReplacementRange(replacementRange)
        let inserted = NSAttributedString(attributedString: content)
        let document = view.manager.stringView.string
        guard isValid(range, in: document), inserted.length <= Int.max - (document.length - range.length) else { return false }
        let caret = NSRange(location: range.location + inserted.length, length: 0)
        return apply(range: range, replacement: inserted, selection: caret, marked: nil)
    }

    /// Replaces the requested document range with marked text. The provided
    /// selection is UTF-16 relative to the new marked text, not the document.
    /// NSNotFound chooses the existing marked range or current selection.
    @discardableResult
    func setMarkedText(_ text: String, selectedRange relativeSelection: NSRange,
                       replacementRange: NSRange, attributes: [NSAttributedString.Key: Any]) -> Bool {
        setMarkedText(NSAttributedString(string: text, attributes: attributes), selectedRange: relativeSelection,
                      replacementRange: replacementRange)
    }

    /// Preserves attributed runs in marked content. The eventual host must keep
    /// temporary input-method decorations out of the persisted document content.
    @discardableResult
    func setMarkedText(_ content: NSAttributedString, selectedRange relativeSelection: NSRange,
                       replacementRange: NSRange) -> Bool {
        // Committed-change publication cannot safely persist provisional IME
        // text until a separate composition overlay has been implemented.
        guard prepareChange == nil, isCurrent else { return false }
        let range = resolvedReplacementRange(replacementRange)
        let inserted = NSAttributedString(attributedString: content)
        let document = view.manager.stringView.string
        guard isValid(range, in: document), inserted.length <= Int.max - (document.length - range.length),
              isValid(relativeSelection, in: inserted.string as NSString) else { return false }
        let selection = NSRange(location: range.location + relativeSelection.location, length: relativeSelection.length)
        let marked = inserted.length == 0 ? nil : NSRange(location: range.location, length: inserted.length)
        return apply(range: range, replacement: inserted, selection: selection, marked: marked)
    }

    /// Clears composition state without changing or notifying document content.
    @discardableResult
    func unmarkText() -> Bool {
        guard isCurrent else { return false }
        if storedMarkedRange != nil {
            storedMarkedRange = nil
            view.noteInputCoordinatesChanged()
        }
        return true
    }

    private var isCurrent: Bool {
        !isApplyingChange && contentMatches
    }

    private var contentMatches: Bool {
        mutationAuthority != nil && view.contentRevision == expectedRevision && view.permitsMutation(with: mutationPermit)
    }

    private func resolvedReplacementRange(_ requested: NSRange) -> NSRange {
        requested.location == NSNotFound ? (storedMarkedRange ?? storedSelection) : requested
    }

    private func apply(range: NSRange, replacement: NSAttributedString,
                       selection: NSRange, marked: NSRange?) -> Bool {
        // Set the guard before invoking the view, whose layout can synchronously
        // deliver AppKit notifications, and retain it through the callback.
        guard let authority = mutationAuthority,
              let transaction = view.beginInputMutation(with: mutationPermit, authority: authority) else { return false }
        isApplyingChange = true
        defer {
            isApplyingChange = false
            view.endInputMutation(transaction)
        }
        let oldSelection = storedSelection
        let oldMarked = storedMarkedRange
        let previous = view.attributedContent(in: range)
        let didChange = !previous.isEqual(to: replacement)
        var prepared: PreparedChange?
        if didChange, let prepareChange = prepareChange {
            let candidate = view.candidateContent(replacing: range, with: replacement)
            guard let accepted = prepareChange(candidate), contentMatches else { return false }
            prepared = accepted
        }
        if didChange {
            guard view.replaceContentReturningRevision(in: range, with: replacement, permit: mutationPermit, transaction: transaction, didCommit: { revision in
                expectedRevision = revision
                storedSelection = selection
                storedMarkedRange = marked
                prepared?.publish()
            }) != nil else { return false }
            // Layout may synchronously notify an outside observer that replaces
            // the document. Never adopt that observer's revision as our own.
            guard contentMatches else { return false }
        } else {
            storedSelection = selection
            storedMarkedRange = marked
        }
        if didChange || oldSelection != storedSelection || oldMarked != storedMarkedRange {
            view.noteInputCoordinatesChanged()
        }
        prepared?.finish()
        if didChange, let contentDidChange = contentDidChange { contentDidChange(view.content) }
        return true
    }

    private func isValid(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return false }
        return isScalarBoundary(range.location, in: text) && isScalarBoundary(range.location + range.length, in: text)
    }

    private func isScalarBoundary(_ offset: Int, in text: NSString) -> Bool {
        guard offset > 0 && offset < text.length else { return true }
        let previous = text.character(at: offset - 1)
        let next = text.character(at: offset)
        return !(0xD800...0xDBFF).contains(previous) || !(0xDC00...0xDFFF).contains(next)
    }
}
#endif
