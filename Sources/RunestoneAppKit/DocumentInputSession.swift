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
/// In prepared sessions, marked edits are provisional and only a committed
/// composition can produce an accepted-content callback.
/// Reentrant session operations are rejected until the callback returns. A
/// external content update makes the session reject operations until refresh.
/// As with the underlying view, attribute values must be treated as immutable.
final class DocumentInputSession {
    /// A prepared change owns a reservation of the canonical document state.
    /// `publish` must only install already validated canonical state. It must
    /// not fail, call out, notify observers, or enter an event loop. `finish`
    /// performs undo registration, synchronization and notifications after the
    /// view has laid out; it must not mutate this session or its view directly.
    /// Undo belongs to the document owner: register at most one logical undo
    /// action for the accepted edit, and close any owned group before returning.
    /// No group may remain open across provisional composition events. The owner
    /// must guard save/undo decisions until edited-state publication is complete.
    enum PublicationConflictPhase {
        case beforeFinish
        case afterFinish
        case afterNotification
    }

    struct PreparedChange {
        let publish: () -> Void
        let finish: () -> Void
        /// Reconciles this ticket without overwriting newer canonical state.
        /// The reservation and session guard remain held during this callback.
        let reconcile: (PublicationConflictPhase) -> Void
    }

    /// Prepares a complete candidate without changing observable state.
    /// nil rejects the edit; returned closures must retain any reservation until
    /// consumed or discarded. The owner must serialize document transactions.
    /// The session and canonical document must begin at the same revision.
    /// The owner holds its gate through layout and finish. If this contract is
    /// violated after publication, the prepared ticket's reconciliation must
    /// preserve newer document state and repair the accepted edit's undo history
    /// before releasing its reservation. Session mutation remains guarded.
    typealias PrepareChange = (NSAttributedString) -> PreparedChange?

    private struct Composition {
        let baseline: NSAttributedString
        let selection: NSRange
        let documentRevision: UUID
        // The host supplies committed typing attributes separately from the
        // marked attributed string, whose runs can contain IME decorations.
        let typingAttributes: [NSAttributedString.Key: Any]
    }

    private enum ChangeKind {
        case ordinary
        case provisional
        case compositionCommit
    }

    private let view: ReadOnlyDocumentView
    private let mutationPermit: ReadOnlyDocumentView.InputMutationPermit?
    private let prepareChange: PrepareChange?
    private let compositionAttributes: (() -> [NSAttributedString.Key: Any])?
    // A side-effect-free, no-callout read that must not enter an event loop.
    // The owner advances it for every canonical content, encoding or metadata
    // replacement before callouts.
    private let documentRevision: (() -> UUID)?
    private let mutationAuthority: ReadOnlyDocumentView.InputMutationAuthority?
    private var expectedRevision: UUID
    private var installedDocumentRevision: UUID?
    /// The canonical revision paired with the currently installed session state.
    var installedRevisionForInput: UUID? { installedDocumentRevision }
    /// Provisional text must be resolved before the owned view is reused.
    var hasProvisionalComposition: Bool { composition != nil }
    private var isApplyingChange = false

    private var storedSelection = NSRange(location: 0, length: 0)
    private var storedMarkedRange: NSRange?
    private var composition: Composition?
    /// The context must disconnect and adopt the canonical document when true.
    /// Queries remain valid so AppKit can safely complete disconnection.
    private(set) var hasDocumentConflict = false
    /// A stale session reports an unavailable selection and no marked range.
    var selectedRange: NSRange { contentMatches ? storedSelection : NSRange(location: NSNotFound, length: 0) }
    var markedRange: NSRange? { contentMatches ? storedMarkedRange : nil }
    var isStale: Bool { !contentMatches }
    var contentDidChange: ((NSAttributedString) -> Void)?

    init(view: ReadOnlyDocumentView, mutationPermit: ReadOnlyDocumentView.InputMutationPermit? = nil,
         prepareChange: PrepareChange? = nil,
         compositionAttributes: (() -> [NSAttributedString.Key: Any])? = nil,
         initialDocumentRevision: UUID? = nil,
         documentRevision: (() -> UUID)? = nil) {
        self.view = view
        self.mutationPermit = mutationPermit
        self.prepareChange = prepareChange
        self.compositionAttributes = compositionAttributes
        self.documentRevision = documentRevision
        // Atomic publication is only valid with exclusive view ownership.
        self.mutationAuthority = (prepareChange == nil || (mutationPermit != nil && initialDocumentRevision != nil && documentRevision != nil))
            ? view.bindInputSession(to: mutationPermit) : nil
        self.expectedRevision = view.contentRevision
        // The owner captures this token atomically with the initial view snapshot.
        // The provider must be a side-effect-free read of the current revision.
        self.installedDocumentRevision = initialDocumentRevision
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

    /// Replaces provisional or stale presentation from a canonical snapshot.
    /// The caller owns the document reservation and has quiesced all input
    /// clients. No accepted-change callback, canonical write or undo occurs.
    @discardableResult
    func adoptCanonicalSnapshot(_ content: NSAttributedString, revision: UUID) -> Bool {
        guard prepareChange != nil, let documentRevision = documentRevision,
              documentRevision() == revision, let authority = mutationAuthority,
              !isApplyingChange,
              let transaction = view.beginInputMutation(with: mutationPermit, authority: authority) else { return false }
        isApplyingChange = true
        defer { isApplyingChange = false; view.endInputMutation(transaction) }
        let range = NSRange(location: 0, length: view.manager.stringView.string.length)
        guard view.replaceContentReturningRevision(in: range, with: content, permit: mutationPermit,
                                                    transaction: transaction, didCommit: { viewRevision in
            expectedRevision = viewRevision
            installedDocumentRevision = revision
            storedSelection = NSRange(location: 0, length: 0)
            storedMarkedRange = nil
            composition = nil
            hasDocumentConflict = false
        }) != nil else { return false }
        view.noteInputCoordinatesChanged()
        guard contentMatches, documentRevision() == revision else {
            hasDocumentConflict = true
            return false
        }
        return true
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
        let inserted: NSAttributedString
        if let composition = composition {
            guard containsMarkedRange(range) else { return false }
            inserted = NSAttributedString(string: content.string, attributes: composition.typingAttributes)
        } else {
            inserted = NSAttributedString(attributedString: content)
        }
        let document = view.manager.stringView.string
        guard isValid(range, in: document), inserted.length <= Int.max - (document.length - range.length) else { return false }
        let caret = NSRange(location: range.location + inserted.length, length: 0)
        return apply(range: range, replacement: inserted, selection: caret, marked: nil,
                     kind: composition == nil ? .ordinary : .compositionCommit)
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

    /// Preserves attributed runs in provisional marked content. Prepared sessions
    /// rebuild committed text using host typing attributes, without IME decoration.
    @discardableResult
    func setMarkedText(_ content: NSAttributedString, selectedRange relativeSelection: NSRange,
                       replacementRange: NSRange) -> Bool {
        guard isCurrent, prepareChange == nil || (compositionAttributes != nil && documentRevision != nil) else { return false }
        let range = resolvedReplacementRange(replacementRange)
        if composition != nil, !containsMarkedRange(range) { return false }
        let inserted = NSAttributedString(attributedString: content)
        let document = view.manager.stringView.string
        guard isValid(range, in: document), inserted.length <= Int.max - (document.length - range.length),
              isValid(relativeSelection, in: inserted.string as NSString) else { return false }
        let selection = NSRange(location: range.location + relativeSelection.location, length: relativeSelection.length)
        let marked = inserted.length == 0 ? nil : NSRange(location: range.location, length: inserted.length)
        return apply(range: range, replacement: inserted, selection: selection, marked: marked,
                     kind: prepareChange == nil ? .ordinary : .provisional)
    }

    /// Finalizes a prepared composition; otherwise clears its marked state.
    @discardableResult
    func unmarkText() -> Bool {
        guard isCurrent else { return false }
        if let composition = composition {
            let range = storedMarkedRange ?? NSRange(location: storedSelection.location, length: 0)
            let raw = view.attributedContent(in: range)
            let clean = NSAttributedString(string: raw.string, attributes: composition.typingAttributes)
            return apply(range: range, replacement: clean, selection: storedSelection,
                         marked: nil, kind: .compositionCommit)
        }
        if storedMarkedRange != nil {
            storedMarkedRange = nil
            view.noteInputCoordinatesChanged()
        }
        return true
    }

    private var isCurrent: Bool {
        !isApplyingChange && !hasDocumentConflict && contentMatches
    }

    private var contentMatches: Bool {
        mutationAuthority != nil && view.contentRevision == expectedRevision && view.permitsMutation(with: mutationPermit)
    }

    private func resolvedReplacementRange(_ requested: NSRange) -> NSRange {
        requested.location == NSNotFound ? (storedMarkedRange ?? storedSelection) : requested
    }

    private func containsMarkedRange(_ range: NSRange) -> Bool {
        guard let marked = storedMarkedRange else { return true }
        guard range.location >= 0, range.length >= 0, range.location <= marked.location,
              range.length <= Int.max - range.location,
              marked.length <= Int.max - marked.location else { return false }
        return range.location + range.length >= marked.location + marked.length
    }

    /// Discards only the local provisional overlay. The caller must also tell
    /// the input context to discard its conversion session before exposing the
    /// view to more input; context discard can itself synchronously call back.
    @discardableResult
    func cancelComposition() -> Bool {
        guard isCurrent, let baseline = composition, let authority = mutationAuthority,
              let transaction = view.beginInputMutation(with: mutationPermit, authority: authority) else { return false }
        isApplyingChange = true
        defer { isApplyingChange = false; view.endInputMutation(transaction) }
        guard documentIsCurrent(), compositionIsCurrent(baseline) else { return false }
        let restored = restore(baseline, selection: baseline.selection, transaction: transaction)
        return restored && documentIsCurrent() && compositionIsCurrent(baseline)
    }

    private func documentIsCurrent() -> Bool {
        guard let installed = installedDocumentRevision, let documentRevision = documentRevision else { return true }
        guard documentRevision() == installed else {
            hasDocumentConflict = true
            return false
        }
        return true
    }

    private func compositionIsCurrent(_ composition: Composition) -> Bool {
        guard let documentRevision = documentRevision,
              documentRevision() == composition.documentRevision else {
            hasDocumentConflict = true
            return false
        }
        return true
    }

    private func restore(_ baseline: Composition, selection: NSRange,
                         transaction: ReadOnlyDocumentView.InputMutationTransaction) -> Bool {
        let range = NSRange(location: 0, length: view.manager.stringView.string.length)
        guard view.replaceContentReturningRevision(in: range, with: baseline.baseline, permit: mutationPermit,
                                                    transaction: transaction, didCommit: { revision in
            expectedRevision = revision
            storedSelection = selection
            storedMarkedRange = nil
            composition = nil
        }) != nil, contentMatches else { return false }
        view.noteInputCoordinatesChanged()
        return true
    }

    private func apply(range: NSRange, replacement: NSAttributedString,
                       selection: NSRange, marked: NSRange?, kind: ChangeKind = .ordinary) -> Bool {
        // Set the guard before invoking the view, whose layout can synchronously
        // deliver AppKit notifications, and retain it through the callback.
        guard let authority = mutationAuthority,
              let transaction = view.beginInputMutation(with: mutationPermit, authority: authority) else { return false }
        isApplyingChange = true
        defer {
            isApplyingChange = false
            view.endInputMutation(transaction)
        }
        let previousComposition = composition
        guard prepareChange == nil || documentIsCurrent() else { return false }
        if case .provisional = kind {
            if let existing = composition {
                guard compositionIsCurrent(existing) else { return false }
            } else {
                guard let compositionAttributes = compositionAttributes, let documentRevision = documentRevision else { return false }
                let revision = documentRevision()
                let baseline = view.content
                let selection = storedSelection
                let attributes = compositionAttributes()
                guard contentMatches, documentIsCurrent(), documentRevision() == revision else {
                    hasDocumentConflict = true
                    return false
                }
                composition = Composition(baseline: baseline, selection: selection, documentRevision: revision,
                                          typingAttributes: attributes)
            }
        }
        let oldSelection = storedSelection
        let oldMarked = storedMarkedRange
        let previous = view.attributedContent(in: range)
        let didChange = !previous.isEqual(to: replacement)
        var prepared: PreparedChange?
        var changesCanonicalText = false
        if case .compositionCommit = kind {
            guard let baseline = composition, let prepareChange = prepareChange,
                  compositionIsCurrent(baseline) else { return false }
            let candidate = view.candidateContent(replacing: range, with: replacement)
            if candidate.string.utf16.elementsEqual(baseline.baseline.string.utf16) {
                let restored = restore(baseline, selection: selection, transaction: transaction)
                return restored && documentIsCurrent() && compositionIsCurrent(baseline)
            }
            let accepted = prepareChange(candidate)
            guard contentMatches, documentIsCurrent(), compositionIsCurrent(baseline) else { return false }
            guard let accepted = accepted else {
                // Rejecting a final candidate abandons the entire overlay;
                // no canonical publication or accepted callback occurs.
                _ = restore(baseline, selection: baseline.selection, transaction: transaction)
                _ = documentIsCurrent()
                return false
            }
            prepared = accepted
            changesCanonicalText = true // Equal-to-baseline text returned above.
        } else if case .ordinary = kind, didChange, let prepareChange = prepareChange {
            let candidate = view.candidateContent(replacing: range, with: replacement)
            let accepted = prepareChange(candidate)
            guard contentMatches, documentIsCurrent(), let accepted = accepted else { return false }
            prepared = accepted
            changesCanonicalText = !candidate.string.utf16.elementsEqual((view.manager.stringView.string as String).utf16)
        }
        if didChange || prepared != nil {
            guard view.replaceContentReturningRevision(in: range, with: replacement, permit: mutationPermit, transaction: transaction, didCommit: { revision in
                expectedRevision = revision
                storedSelection = selection
                storedMarkedRange = marked
                if case .compositionCommit = kind { composition = nil }
                let previousDocumentRevision = installedDocumentRevision
                prepared?.publish()
                if prepared != nil, let documentRevision = documentRevision {
                    let publishedRevision = documentRevision()
                    if changesCanonicalText && publishedRevision == previousDocumentRevision {
                        hasDocumentConflict = true
                    }
                    installedDocumentRevision = publishedRevision
                }
            }) != nil else {
                composition = previousComposition
                return false
            }
            // Layout may synchronously notify an outside observer that replaces
            // the document. Never adopt that observer's revision as our own.
            guard contentMatches else {
                if let prepared = prepared { prepared.reconcile(.beforeFinish); return true }
                return false
            }
        } else {
            storedSelection = selection
            storedMarkedRange = marked
        }
        if didChange || oldSelection != storedSelection || oldMarked != storedMarkedRange {
            view.noteInputCoordinatesChanged()
        }
        // A document owner must hold its reservation through finish. If it
        // nevertheless changes during layout, do not register undo out of order;
        // hand the already-published conflict to the owner's reconciliation path.
        if prepared != nil && (!contentMatches || hasDocumentConflict || !documentIsCurrent()) {
            prepared?.reconcile(.beforeFinish)
            return true
        }
        prepared?.finish()
        if prepared != nil && (!contentMatches || hasDocumentConflict || !documentIsCurrent()) {
            prepared?.reconcile(.afterFinish)
            return true
        }
        if case .provisional = kind {
            guard let composition = composition else { return false }
            return documentIsCurrent() && compositionIsCurrent(composition)
        }
        if didChange || prepared != nil, let contentDidChange = contentDidChange { contentDidChange(view.snapshotForInputSession()) }
        if prepared != nil && (!contentMatches || hasDocumentConflict || !documentIsCurrent()) {
            prepared?.reconcile(.afterNotification)
        }
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
