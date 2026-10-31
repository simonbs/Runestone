#if canImport(AppKit)
import AppKit

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

/// An explicit, document-owned connection to a prepared editable AppKit view.
///
/// Keep this object alive while the view is installed. The host owns its own
/// lifetime sentinel and bridge; the attachment does not keep the host alive.
/// Install `view` in the app's view hierarchy after a successful attachment.
/// Construction never makes it first responder. All calls run on the main
/// thread. This opt-in API does not assert that interactive input or assistive
/// technology has been validated for release.
public final class RunestoneEditableDocumentAttachment {
    /// An input snapshot captured against the currently installed revision.
    /// A nil state means the input context is inactive, stale, or resetting.
    public struct InputState: Equatable {
        public let selection: NSRange
        /// nil when there is no visible marked range. An empty provisional
        /// composition can still exist; inspect `hasComposition` separately.
        public let markedRange: NSRange?
        public let hasComposition: Bool
    }

    /// An immutable selection captured together with its matching text.
    /// Ranges use AppKit's UTF-16 coordinate space. A caret is represented by
    /// an empty string and a zero-length range rather than nil.
    public struct SelectionSnapshot: Equatable {
        public let range: NSRange
        public let text: String
    }

    /// The newly created document view. Do not attempt to attach it again.
    public let view: ReadOnlyDocumentView
    private var attachment: PreparedInputDocumentAttachment?
    private var detaching = false
    private var detached = false

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
                              logicalNewlinePlanner: @escaping RunestoneLogicalNewlinePlanner = { _ in nil })
        -> RunestoneEditableDocumentAttachment? {
        precondition(Thread.isMainThread)
        guard let attachment = PreparedInputDocumentAttachment.attachResponder(
            host: host, lifetime: lifetime, bridge: bridge, logicalNewlinePlanner: logicalNewlinePlanner
        ) else { return nil }
        return RunestoneEditableDocumentAttachment(attachment)
    }

    /// Whether the connection is available for editing or an explicit focus
    /// request. Focus itself is not implied. Reset, a pending history request,
    /// or an executing history action can temporarily make this false.
    public var isEditable: Bool {
        precondition(Thread.isMainThread)
        guard !detaching, !detached, let attachment = attachment else { return false }
        return attachment.connection.isConnectedForEditing
    }

    /// A revision-checked input state, when its input context is active.
    public var inputState: InputState? {
        precondition(Thread.isMainThread)
        guard isEditable, let state = attachment?.connection.inputState() else { return nil }
        return InputState(selection: state.selection, markedRange: state.marked,
                          hasComposition: state.hasComposition)
    }

    /// A revision-checked selection snapshot suitable for validating and
    /// preparing read-only operations such as Share or Services. Returns nil
    /// while input is inactive, stale, resetting, or detached. Callers should
    /// require a nonempty range before offering a selected-text operation.
    public var selectionSnapshot: SelectionSnapshot? {
        precondition(Thread.isMainThread)
        guard isEditable, let snapshot = attachment?.connection.selectionSnapshot() else { return nil }
        return SelectionSnapshot(range: snapshot.range, text: snapshot.text)
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
