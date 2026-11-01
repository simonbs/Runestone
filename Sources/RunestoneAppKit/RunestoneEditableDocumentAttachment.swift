#if canImport(AppKit)
import AppKit
import RunestoneSyntax

/// The immutable input supplied to a host-owned logical-Return planner.
///
/// The planner runs synchronously on the main thread after the framework has
/// acquired the document input reservation. It must be side-effect-free and
/// must not enter an event loop. Returning nil preserves Runestone's ordinary
/// contextual-newline insertion.
public struct RunestoneLogicalNewlineContext {
    public let text: String
    public let selection: NSRange
    public let lineEnding: String

    public init(text: String, selection: NSRange, lineEnding: String) {
        self.text = text
        self.selection = selection
        self.lineEnding = lineEnding
    }
}

/// A host-planned logical-Return edit, expressed in UTF-16 document ranges.
///
/// This supports both language indentation (which commonly replaces the
/// selection) and transformations such as Markdown continuation/termination
/// (which may replace a prefix before the caret). Invalid edits are rejected
/// without falling back to a second insertion.
public struct RunestoneLogicalNewlineEdit {
    public let replacementRange: NSRange
    public let replacementText: String
    public let selectedRange: NSRange

    public init(replacementRange: NSRange, replacementText: String, selectedRange: NSRange) {
        self.replacementRange = replacementRange
        self.replacementText = replacementText
        self.selectedRange = selectedRange
    }
}

public typealias RunestoneLogicalNewlinePlanner = (RunestoneLogicalNewlineContext) -> RunestoneLogicalNewlineEdit?

/// The immutable input supplied to a host-owned Tab/Backtab planner.
///
/// The planner is invoked only for AppKit's explicit `insertTab:` or
/// `insertBacktab:` command after document-gate admission. Literal tab payloads
/// supplied through `insertText` and marked text never use this policy.
public struct RunestoneTabContext {
    public enum Direction { case forward, backward }

    public let text: String
    public let selection: NSRange
    public let direction: Direction

    public init(text: String, selection: NSRange, direction: Direction) {
        self.text = text
        self.selection = selection
        self.direction = direction
    }
}

/// One atomic Tab/Backtab edit expressed in UTF-16 document coordinates.
public struct RunestoneTabEdit {
    public let replacementRange: NSRange
    public let replacementText: String
    public let selectedRange: NSRange

    public init(replacementRange: NSRange, replacementText: String, selectedRange: NSRange) {
        self.replacementRange = replacementRange
        self.replacementText = replacementText
        self.selectedRange = selectedRange
    }
}

public typealias RunestoneTabPlanner = (RunestoneTabContext) -> RunestoneTabEdit?

/// One host-owned editor command applied through the ordinary document input
/// reservation and undo path. Both ranges use UTF-16 document coordinates.
/// Invalid, stale, read-only, composing, or detached requests fail atomically.
public struct RunestoneHostEdit {
    public let replacementRange: NSRange
    public let replacementText: String
    public let selectedRange: NSRange

    public init(replacementRange: NSRange, replacementText: String, selectedRange: NSRange) {
        self.replacementRange = replacementRange
        self.replacementText = replacementText
        self.selectedRange = selectedRange
    }
}

/// An explicit, document-owned connection to a prepared editable AppKit view.
///
/// Keep this object alive while the view is installed. The host owns its own
/// lifetime sentinel and bridge; the attachment does not keep the host alive.
/// Install `view` in the app's view hierarchy after a successful attachment.
/// Construction never makes it first responder. All calls run on the main
/// thread. This opt-in API does not assert that interactive input or assistive
/// technology has been validated for release.
public final class RunestoneEditableDocumentAttachment {
    /// The end of a selection whose visual identity is represented by
    /// `caretAffinity`. A collapsed selection uses `caret`.
    public enum SelectionEndpoint: Equatable { case caret, lowerBound, upperBound }

    /// Additive presentation identity for a caret that shares its UTF-16
    /// offset with another visual position.
    public struct CaretAffinity: Equatable {
        public enum WrapSide: Equatable { case upstream, downstream }
        public enum BidirectionalSide: Equatable { case primary, secondary }
        public let wrapSide: WrapSide?
        public let bidirectionalSide: BidirectionalSide?

        public init(wrapSide: WrapSide?, bidirectionalSide: BidirectionalSide?) {
            self.wrapSide = wrapSide
            self.bidirectionalSide = bidirectionalSide
        }
    }
    /// An input snapshot captured against the currently installed revision.
    /// A nil state means the input context is inactive, stale, or resetting.
    public struct InputState: Equatable {
        public let selection: NSRange
        /// nil when there is no visible marked range. An empty provisional
        /// composition can still exist; inspect `hasComposition` separately.
        public let markedRange: NSRange?
        public let hasComposition: Bool
        /// The selection end that keyboard and pointer extension will move.
        public let activeEndpoint: SelectionEndpoint
        /// nil when the active end has one unambiguous visual position.
        public let caretAffinity: CaretAffinity?
    }

    /// An immutable selection captured together with its matching text.
    /// Ranges use AppKit's UTF-16 coordinate space. A caret is represented by
    /// an empty string and a zero-length range rather than nil.
    public struct SelectionSnapshot: Equatable {
        public let range: NSRange
        public let text: String
        /// The selection end whose presentation identity was captured.
        public let activeEndpoint: SelectionEndpoint
        /// nil when the active end has one unambiguous visual position.
        public let caretAffinity: CaretAffinity?

        public init(range: NSRange, text: String,
                    activeEndpoint: SelectionEndpoint? = nil, caretAffinity: CaretAffinity? = nil) {
            self.range = range
            self.text = text
            self.activeEndpoint = activeEndpoint ?? (range.length == 0 ? .caret : .upperBound)
            self.caretAffinity = caretAffinity
        }
    }

    /// A complete immutable text snapshot used by an app-owned native
    /// `NSTextFinderClient`. The text and selection are captured against one
    /// installed document revision. Nil means input is inactive, stale,
    /// resetting, detached, or has a provisional composition.
    public struct TextFinderSnapshot: Equatable {
        public let text: String
        public let selection: NSRange

        public init(text: String, selection: NSRange) {
            self.text = text
            self.selection = selection
        }
    }

    /// The newly created document view. Do not attempt to attach it again.
    public let view: ReadOnlyDocumentView
    private var attachment: PreparedInputDocumentAttachment?
    private var detaching = false
    private var detached = false

    /// Handles file URLs dropped on the editor. Text drops remain framework-
    /// owned edits; file URLs are delegated because only the host owns document opening.
    public var fileDropHandler: (([URL]) -> Bool)? {
        get { (view as? PreparedInputResponderView)?.fileDropHandler }
        set { (view as? PreparedInputResponderView)?.fileDropHandler = newValue }
    }

    private init(_ attachment: PreparedInputDocumentAttachment) {
        self.attachment = attachment
        self.view = attachment.view
    }

    /// Captures the initial document snapshot under the host's reconstruction
    /// gate and creates a new input view. Returns nil if that gate is busy, the
    /// document was invalidated, or the initial snapshot could not be adopted.
    /// The host must implement the complete dispatch gate contract and retain
    /// its lifetime sentinel and bridge independently of this attachment.
    public static func attach(host: RunestoneInputDispatchHost,
                              lifetime: RunestoneInputDocumentLifetime,
                              bridge: RunestoneInputDocumentBridge,
                              logicalNewlinePlanner: @escaping RunestoneLogicalNewlinePlanner = { _ in nil },
                              tabPlanner: RunestoneTabPlanner? = nil)
        -> RunestoneEditableDocumentAttachment? {
        precondition(Thread.isMainThread)
        guard let attachment = PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: lifetime, bridge: bridge, logicalNewlinePlanner: logicalNewlinePlanner,
            tabPlanner: tabPlanner
        ) else { return nil }
        return RunestoneEditableDocumentAttachment(attachment)
    }

    /// Whether the connection is available for editing or an explicit focus
    /// request. Focus itself is not implied. Reset, a pending history request,
    /// or an executing history action can temporarily make this false.
    public var isEditable: Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached, let attachment = attachment else { return false }
        guard let responder = view as? PreparedInputResponderView,
              !responder.isReadOnly else { return false }
        return attachment.connection.isConnectedForEditing
    }

    /// Whether the attached surface is intentionally noneditable while its
    /// document connection remains alive. This differs from a temporary reset
    /// or busy gate, which also makes `isEditable` false.
    public var isReadOnly: Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached,
              let responder = view as? PreparedInputResponderView else { return false }
        return responder.isReadOnly
    }

    /// Changes the surface between editable and read-only modes without
    /// replacing its view or canonical document snapshot. Entering read-only
    /// mode cancels active composition through the normal focus-loss path.
    /// Returning false means no state changed (for example, AppKit refused to
    /// relinquish first responder).
    @discardableResult
    public func setReadOnly(_ readOnly: Bool) -> Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached,
              let responder = view as? PreparedInputResponderView else { return false }
        return responder.setReadOnly(readOnly)
    }

    /// A revision-checked input state, when its input context is active.
    public var inputState: InputState? {
        precondition(Thread.isMainThread)
        guard isEditable, let state = attachment?.connection.inputState() else { return nil }
        return InputState(selection: state.selection, markedRange: state.marked,
                          hasComposition: state.hasComposition,
                          activeEndpoint: Self.publicEndpoint(state.selectionState),
                          caretAffinity: Self.publicAffinity(state.selectionState))
    }

    /// A revision-checked selection snapshot suitable for validating and
    /// preparing read-only operations such as Share or Services. Returns nil
    /// while input is inactive, stale, resetting, or detached. Callers should
    /// require a nonempty range before offering a selected-text operation.
    public var selectionSnapshot: SelectionSnapshot? {
        precondition(Thread.isMainThread)
        guard isEditable, let snapshot = attachment?.connection.selectionSnapshot() else { return nil }
        return SelectionSnapshot(range: snapshot.state.range, text: snapshot.text,
                                 activeEndpoint: Self.publicEndpoint(snapshot.state),
                                 caretAffinity: Self.publicAffinity(snapshot.state))
    }

    /// A revision-checked native text-service selection. The text is captured
    /// with its UTF-16 range and is unavailable during composition or reset.
    public var selectedTextSnapshot: SelectionSnapshot? { selectionSnapshot }

    private static func publicEndpoint(_ state: InputSelectionState) -> SelectionEndpoint {
        switch state.activeEndpoint {
        case .caret: return .caret
        case .lowerBound: return .lowerBound
        case .upperBound: return .upperBound
        }
    }

    private static func publicAffinity(_ state: InputSelectionState) -> CaretAffinity? {
        guard let affinity = state.affinity else { return nil }
        let wrap: CaretAffinity.WrapSide? = switch affinity.wrapSide {
        case .upstream: .upstream
        case .downstream: .downstream
        case nil: nil
        }
        let bidi: CaretAffinity.BidirectionalSide? = switch affinity.bidirectionalSide {
        case .primary: .primary
        case .secondary: .secondary
        case nil: nil
        }
        return CaretAffinity(wrapSide: wrap, bidirectionalSide: bidi)
    }

    /// The currently presented UTF-16 selection, including while the editor is
    /// read-only. Unlike `selectionSnapshot`, this does not imply active input
    /// or provide provisional text and is intended for presentation/navigation.
    public var presentedSelectionRange: NSRange? {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return nil }
        return view.presentedSelectionRange
    }

    public var textFinderSnapshot: TextFinderSnapshot? {
        precondition(Thread.isMainThread)
        guard isEditable, let snapshot = attachment?.connection.textFinderSnapshot() else { return nil }
        return TextFinderSnapshot(text: snapshot.text, selection: snapshot.selection)
    }

    /// Selects one UTF-16 range through the document input gate. This is the
    /// primitive used by the app-owned native find client for match navigation.
    @discardableResult
    public func selectForTextFinder(_ range: NSRange) -> Bool {
        precondition(Thread.isMainThread)
        guard isEditable else { return false }
        return attachment?.connection.setSelectionForTextFinder(range) == true
    }

    /// Replaces one UTF-16 range through the ordinary input transaction and
    /// undo path. AppKit calls Replace All from the end of the document toward
    /// the beginning, so each accepted replacement remains range-stable.
    @discardableResult
    public func replaceForTextFinder(in range: NSRange, with string: String) -> Bool {
        precondition(Thread.isMainThread)
        guard isEditable else { return false }
        return attachment?.connection.replaceForTextFinder(range, with: string) == true
    }

    /// Replaces a UTF-16 range through the document reservation and undo path.
    /// Literal payloads are not normalized, so CR, LF and CRLF remain intact.
    @discardableResult
    public func replaceText(in range: NSRange, with string: String) -> Bool {
        precondition(Thread.isMainThread)
        guard isEditable else { return false }
        return attachment?.connection.replaceForTextFinder(range, with: string) == true
    }

    /// Applies one host-planned editor transformation and publishes its final
    /// selection as a single coordinated input operation. Literal replacement
    /// bytes are preserved; the framework never retries a rejected command.
    @discardableResult
    public func applyHostEdit(_ edit: RunestoneHostEdit) -> Bool {
        precondition(Thread.isMainThread)
        guard isEditable else { return false }
        return attachment?.connection.applyHostEdit(edit) == true
    }

    /// Scrolls the match's wrapped fragment into view without changing canonical
    /// text. Selection should be applied first so the normal caret publication
    /// and accessibility notifications describe the same match.
    public func scrollTextFinderRangeToVisible(_ range: NSRange) {
        precondition(Thread.isMainThread)
        guard isEditable else { return }
        view.scrollTextFinderRangeToVisible(range)
    }

    /// Selects and reveals one canonical UTF-16 document range. Editable
    /// attachments publish the selection through the document input gate;
    /// read-only attachments retain a presentation-only selection so native
    /// navigation such as Go to Line remains useful without enabling edits.
    @discardableResult
    public func selectAndRevealDocumentRange(_ range: NSRange) -> Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return false }
        if isEditable {
            guard attachment?.connection.setSelectionForTextFinder(range) == true else { return false }
            view.scrollTextFinderRangeToVisible(range)
            return true
        }
        return view.selectAndRevealDocumentRange(range)
    }

    /// Returns conservative view-local geometry only for a fully visible
    /// match. NSTextFinder tolerates an empty result while layout catches up.
    public func textFinderRects(for range: NSRange) -> [NSRect] {
        precondition(Thread.isMainThread)
        guard isEditable, let window = view.window else { return [] }
        let screen = view.accessibilityFrame(for: range)
        guard !screen.isEmpty else { return [] }
        return [view.convert(window.convertFromScreen(screen), from: nil)]
    }

    /// Applies presentation-only options without changing canonical document state.
    public func applyDisplayConfiguration(_ configuration: RunestoneEditorDisplayConfiguration) {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return }
        view.displayConfiguration = configuration
    }

    /// Applies semantic syntax presentation without changing document state.
    public func applySyntaxConfiguration(_ configuration: RunestoneAppKitSyntaxConfiguration?) {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return }
        view.applySyntaxConfiguration(configuration)
    }

    /// Returns fold ranges for the currently parsed document generation.
    public func syntaxFolds(completion: @escaping (Result<[RunestoneSyntaxFold], RunestoneSyntaxError>) -> Void) {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else {
            completion(.failure(.cancelled))
            return
        }
        view.syntaxFolds(completion: completion)
    }

    public var syntaxFoldRows: [Int] {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return [] }
        return view.syntaxFoldRows
    }

    public var syntaxFoldRowAtSelection: Int? {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return nil }
        return view.syntaxFoldRowAtSelection
    }

    public func isSyntaxFoldCollapsed(atRow row: Int) -> Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return false }
        return view.isSyntaxFoldCollapsed(atRow: row)
    }

    @discardableResult
    public func toggleSyntaxFold(atRow row: Int) -> Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return false }
        return view.toggleSyntaxFold(atRow: row)
    }

    public func foldAllSyntax() {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return }
        view.foldAllSyntax()
    }

    public func unfoldAllSyntax() {
        precondition(Thread.isMainThread)
        guard !detaching, !detached else { return }
        view.unfoldAllSyntax()
    }

    /// Ask the containing window to make this view first responder. Returns
    /// false when detached, unavailable, or not installed in a window. A true
    /// result is window acceptance, not proof that the window is key or an
    /// input method has activated; focus is managed by AppKit. Eligibility is
    /// revoked when focus or key-window status is lost, so the host must make
    /// a new explicit request before focusing the view again.
    @discardableResult
    public func requestFirstResponder() -> Bool {
        precondition(Thread.isMainThread)
        guard isEditable, let window = view.window,
              let responder = view as? PreparedInputResponderView else { return false }
        guard responder.requestFocusEligibility() else { return false }
        let accepted = window.makeFirstResponder(view)
        if !accepted { responder.revokeFocusEligibility() }
        return accepted
    }

    /// Immediately disarms input, then attempts to retire the input context.
    /// If false, retain this object and retry after the host gate becomes
    /// available or the active input call unwinds. True means cleanup completed.
    /// This attachment and its view never become editable again. Detachment
    /// does not change the window's first responder; the host manages focus
    /// transfer. Releasing an attachment before cleanup completes quarantines
    /// its view and defers cleanup.
    @discardableResult
    public func detach() -> Bool {
        precondition(Thread.isMainThread)
        if detached { return true }
        guard let attachment = attachment else { return false }
        if !detaching {
            detaching = true
            (view as? PreparedInputResponderView)?.disarmForDetachment()
        }
        guard attachment.disconnect() else { return false }
        detached = true
        self.attachment = nil
        return true
    }
}
#endif
