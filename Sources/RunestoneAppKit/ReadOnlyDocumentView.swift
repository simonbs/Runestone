#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// A read-only, wrapping Core Text view of an attributed document snapshot.
///
/// Install this view as an `NSScrollView`'s document view. Supply text with
/// appropriate AppKit font and foreground color attributes. Input, selection,
/// interactive editing are not provided by this view. Accessibility exposes
/// read-only text and geometry when a current layout is available.
public class ReadOnlyDocumentView: NSView {
    final class InputMutationPermit {
        fileprivate var hasSession = false
        fileprivate init() {}
    }

    final class InputMutationAuthority {
        fileprivate init() {}
    }
    final class InputMutationTransaction {
        fileprivate init() {}
    }

    private let retirementLock = NSLock()
    private var retired = false
    private var retirementFinished = false
    private var accessibilityValueNotificationPending = false
    private var accessibilitySelectionNotificationPending = false
    private var accessibilityValueDirty = false
    private var accessibilitySelectionDirty = false
    var accessibilityNotificationPoster: (ReadOnlyDocumentView, NSAccessibility.Notification) -> Void = {
        NSAccessibility.post(element: $0, notification: $1)
    }
    var isRetired: Bool {
        retirementLock.lock()
        defer { retirementLock.unlock() }
        return retired
    }
    private var inputMutationPermit: InputMutationPermit?
    private var inputMutationAuthority: InputMutationAuthority?
    private var activeInputTransaction: InputMutationTransaction?
    private var inputMutationDepth = 0
    private var pendingInputPermitRelease: InputMutationPermit?
    var inputMutationInFlight: Bool { inputMutationDepth != 0 }
    private var snapshot: NSMutableAttributedString
    private(set) var contentRevision = UUID()
    private let fallbackHeight: CGFloat
    private let cacheLimit = 128
    private(set) var manager: LineManager
    private var controllers: [DocumentLineNodeID: LogicalLineLayoutController] = [:]
    private var controllerOrder: [DocumentLineNodeID] = []
    private var coordinator: ViewportLayoutCoordinator!
    private var layoutWidth: CGFloat = 0
    private var boundsObserver: NSObjectProtocol?
    private var windowObservers: [NSObjectProtocol] = []
    let inputInvalidation: InputInvalidationDelivery
    private(set) var inputGeometryRevision = UUID()
    /// Tracks selection/composition changes independently of viewport layout.
    private(set) var inputSelectionRevision = UUID()
    private(set) var updatingViewport = false
    private var pendingViewportUpdate = false
    private var boundedViewportBudget: PreparedInputViewportWorkBudget?
    private weak var boundedAbortClip: NSClipView?
    private var boundedAbortBounds: CGRect?
    private var boundedAbortContentRevision: UUID?
    private var boundedAbortGeneration = UUID()
    private var viewportUpdateScheduled = false
    private var viewportRetryCount = 0
    private var viewportRetryExhausted = false
    private var viewportRecoveryScheduled = false
    private var viewportRecoveryToken = UUID()
    private var viewportRecoveryDelay: TimeInterval = 0.05
    private let viewportRecoveryScheduler: (TimeInterval, @escaping () -> Void) -> Void
    private let viewportRecoveryClock: () -> TimeInterval
    private weak var exhaustedClip: NSClipView?
    private var exhaustedBounds: CGRect?
    private var exhaustedContentRevision: UUID?
    private var updatingContentRevision: UUID?
    private weak var updatingClip: NSClipView?
    private var updatingBounds: CGRect?
    private(set) var visibleLayout: ViewportLayoutCoordinator.Result?

    public override var isFlipped: Bool { true }

    public override var isHidden: Bool {
        get { isRetired || super.isHidden }
        set { super.isHidden = isRetired || newValue }
    }

    struct AccessibilityTextState {
        let text: String
        let selection: NSRange?
        let revision: UUID
    }

    /// Owned input views must provide their own revision-checked snapshot.
    func accessibilityTextState() -> AccessibilityTextState? {
        guard !isRetired, inputMutationPermit == nil else { return nil }
        let revision = contentRevision
        let text = snapshot.string
        guard !isRetired, inputMutationPermit == nil, contentRevision == revision else { return nil }
        return AccessibilityTextState(text: text, selection: nil, revision: revision)
    }

    public override func isAccessibilityElement() -> Bool {
        !isRetired && !isHiddenOrHasHiddenAncestor && accessibilityTextState() != nil
    }

    public override func accessibilityChildren() -> [Any]? {
        isRetired ? [] : super.accessibilityChildren()
    }

    public override func accessibilityRole() -> NSAccessibility.Role? {
        isRetired ? nil : .staticText
    }

    public override func accessibilityValue() -> Any? {
        accessibilityTextState()?.text
    }

    public override func accessibilityNumberOfCharacters() -> Int {
        accessibilityTextState().map { ($0.text as NSString).length } ?? 0
    }

    public override func accessibilitySelectedTextRange() -> NSRange {
        accessibilityTextState()?.selection ?? NSRange(location: NSNotFound, length: 0)
    }

    public override func accessibilitySelectedText() -> String? {
        guard let state = accessibilityTextState(), let range = state.selection,
              validAccessibilityRange(range, in: state.text as NSString) else { return nil }
        return (state.text as NSString).substring(with: range)
    }

    public override func accessibilityString(for range: NSRange) -> String? {
        guard let state = accessibilityTextState(), validAccessibilityRange(range, in: state.text as NSString) else { return nil }
        return (state.text as NSString).substring(with: range)
    }

    public override func accessibilityRange(for index: Int) -> NSRange {
        let unavailable = NSRange(location: NSNotFound, length: 0)
        guard let state = accessibilityTextState() else { return unavailable }
        let text = state.text as NSString
        guard index >= 0, index < text.length else { return unavailable }
        return text.rangeOfComposedCharacterSequence(at: index)
    }

    public override func accessibilityLine(for index: Int) -> Int {
        guard let state = accessibilityTextState(), index >= 0, index <= (state.text as NSString).length,
              contentRevision == state.revision, let line = manager.line(containingCharacterAt: index),
              !isRetired, contentRevision == state.revision else { return NSNotFound }
        return line.index
    }

    public override func accessibilityRange(forLine line: Int) -> NSRange {
        let unavailable = NSRange(location: NSNotFound, length: 0)
        guard let state = accessibilityTextState(), line >= 0, line < manager.lineCount,
              contentRevision == state.revision else { return unavailable }
        let node = manager.line(atRow: line)
        guard !isRetired, contentRevision == state.revision else { return unavailable }
        return NSRange(location: node.location, length: node.data.totalLength)
    }

    public override func accessibilityVisibleCharacterRange() -> NSRange {
        let unavailable = NSRange(location: NSNotFound, length: 0)
        guard let state = accessibilityTextState(), let range = AccessibilityTextGeometry.visibleRange(in: self),
              !isRetired, contentRevision == state.revision,
              accessibilityTextState()?.revision == state.revision else { return unavailable }
        return range
    }

    public override func accessibilityFrame(for range: NSRange) -> NSRect {
        guard let state = accessibilityTextState(), validAccessibilityRange(range, in: state.text as NSString),
              let frame = AccessibilityTextGeometry.frame(for: range, in: self),
              !isRetired, contentRevision == state.revision,
              accessibilityTextState()?.revision == state.revision else { return .zero }
        return frame
    }

    public override func accessibilityRange(for point: NSPoint) -> NSRange {
        let unavailable = NSRange(location: NSNotFound, length: 0)
        guard let state = accessibilityTextState(), let range = AccessibilityTextGeometry.range(at: point, in: self),
              !isRetired, contentRevision == state.revision,
              accessibilityTextState()?.revision == state.revision else { return unavailable }
        return range
    }

    public override func isAccessibilitySelectorAllowed(_ selector: Selector) -> Bool {
        if selector == NSSelectorFromString("setAccessibilityValue:") ||
            selector == NSSelectorFromString("setAccessibilitySelectedTextRange:") ||
            selector == NSSelectorFromString("setAccessibilitySelectedText:") ||
            selector == NSSelectorFromString("setAccessibilitySelectedTextRanges:") { return false }
        return super.isAccessibilitySelectorAllowed(selector)
    }

    func scheduleAccessibilityValueChanged() {
        guard !isRetired else { return }
        accessibilityValueDirty = true
        flushAccessibilityNotificationsIfNeeded()
    }

    func invalidateInputSelectionTracking() {
        guard !isRetired else { return }
        inputSelectionRevision = UUID()
    }

    func scheduleAccessibilitySelectionChanged() {
        guard !isRetired else { return }
        invalidateInputSelectionTracking()
        accessibilitySelectionDirty = true
        flushAccessibilityNotificationsIfNeeded()
    }

    /// A suppressed input context keeps its dirty flags until it is active
    /// again; a queued turn alone does not imply that accessibility can read it.
    func flushAccessibilityNotificationsIfNeeded() {
        guard !isRetired else { return }
        if accessibilityValueDirty && !accessibilityValueNotificationPending {
            accessibilityValueNotificationPending = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let available = self.accessibilityTextState() != nil && !self.isRetired
                self.accessibilityValueNotificationPending = false
                guard self.accessibilityValueDirty, available else { return }
                self.accessibilityValueDirty = false
                self.accessibilityNotificationPoster(self, .valueChanged)
            }
        }
        if accessibilitySelectionDirty && !accessibilitySelectionNotificationPending {
            accessibilitySelectionNotificationPending = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let available = self.accessibilityTextState()?.selection != nil && !self.isRetired
                self.accessibilitySelectionNotificationPending = false
                guard self.accessibilitySelectionDirty, available else { return }
                self.accessibilitySelectionDirty = false
                self.accessibilityNotificationPoster(self, .selectedTextChanged)
            }
        }
    }

    private func validAccessibilityRange(_ range: NSRange, in text: NSString) -> Bool {
        range.location >= 0 && range.length >= 0 && range.location <= text.length &&
            range.length <= text.length - range.location &&
            isScalarBoundary(range.location, in: text) && isScalarBoundary(range.location + range.length, in: text)
    }

    public override var acceptsFirstResponder: Bool {
        !isRetired && super.acceptsFirstResponder
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        isRetired ? nil : super.hitTest(point)
    }

    /// Permanently quarantines a view whose input owner was unexpectedly lost.
    /// The no-callout flag can be set on any thread; AppKit cleanup runs on main.
    func retireInputView() {
        guard markInputViewRetired() else { return }
        if Thread.isMainThread { finishRetirement() }
        else { DispatchQueue.main.async { [self] in finishRetirement() } }
    }

    /// Immediately prevents access without AppKit callouts, including on main.
    /// Keep the view alive until its deferred main-thread cleanup has completed.
    func quarantineInputViewWithoutCallouts() {
        guard markInputViewRetired() else { return }
        DispatchQueue.main.async { [self] in finishRetirement() }
    }

    private func markInputViewRetired() -> Bool {
        retirementLock.lock()
        defer { retirementLock.unlock() }
        guard !retired else { return false }
        retired = true
        return true
    }

    private func finishRetirement() {
        guard !retirementFinished else { return }
        retirementFinished = true
        visibleLayout = nil
        pendingViewportUpdate = false
        viewportRecoveryToken = UUID()
        inputInvalidation.detach()
        if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
        boundsObserver = nil
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        super.isHidden = true
        if let window = window, let responder = window.firstResponder as? NSView,
           responder === self || responder.isDescendant(of: self) {
            _ = window.makeFirstResponder(nil)
        }
        removeFromSuperview()
    }

    /// Creates a view containing a copy of the supplied attributed string.
    /// Attribute values are not deep-copied and should be treated as immutable.
    public convenience init(content: NSAttributedString) {
        self.init(snapshot: content, fallbackHeight: 16)
    }

    /// A copy of the current document snapshot, or an empty snapshot after this
    /// view has been permanently retired by an internal input owner.
    public var content: NSAttributedString {
        guard !isRetired else { return NSAttributedString(string: "") }
        return NSAttributedString(attributedString: snapshot)
    }

    /// The input session uses this only while holding its view transaction.
    func snapshotForInputSession() -> NSAttributedString { NSAttributedString(attributedString: snapshot) }

    /// Replaces the snapshot and resets the scroll position to the start.
    /// Subsequent mutations of the attributed string do not affect the view;
    /// attribute values themselves are not deep-copied. Rebuilding layout takes
    /// time proportional to the size of the document. While an internal input
    /// host owns the view, direct replacements are ignored.
    public func setContent(_ content: NSAttributedString) {
        _ = setContentReturningRevision(content)
    }

    /// Publishes the fully installed model before any layout notification can run.
    /// The synchronous hook must only publish matching internal session state.
    @discardableResult
    func setContentReturningRevision(_ content: NSAttributedString, permit: InputMutationPermit? = nil,
                                     transaction: InputMutationTransaction? = nil,
                                     didCommit: (UUID) -> Void = { _ in }) -> UUID? {
        guard allowsMutation(with: permit, transaction: transaction) else { return nil }
        inputInvalidation.suspend()
        defer { inputInvalidation.resume() }
        snapshot = NSMutableAttributedString(attributedString: content)
        let revision = UUID()
        contentRevision = revision
        resetLayout(width: 0)
        didCommit(revision)
        scheduleAccessibilityValueChanged()
        noteInputCoordinatesChanged()
        needsDisplay = true
        if let scroll = enclosingScrollView {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        updateViewport()
        return revision
    }

    /// Replaces a UTF-16 range with attributed content without resetting the document.
    ///
    /// Returns `false` and leaves the document unchanged if the range is out of
    /// bounds or either endpoint splits a UTF-16 surrogate pair. The supplied
    /// attributed string is copied; its attribute values are not deep-copied.
    /// The scroll position is clamped after layout, but a particular text anchor
    /// is not guaranteed to stay at the same screen position. This programmatic
    /// operation does not provide input, selection, undo, or change notifications.
    /// Returns `false` while an internal input host owns the view.
    @discardableResult
    public func replaceContent(in range: NSRange, with content: NSAttributedString) -> Bool {
        replaceContentReturningRevision(in: range, with: content) != nil
    }

    /// Publishes the fully installed model before any layout notification can run.
    /// The synchronous hook must only publish matching internal session state.
    func replaceContentReturningRevision(in range: NSRange, with content: NSAttributedString,
                                         permit: InputMutationPermit? = nil,
                                         transaction: InputMutationTransaction? = nil,
                                         didCommit: (UUID) -> Void = { _ in }) -> UUID? {
        guard allowsMutation(with: permit, transaction: transaction) else { return nil }
        inputInvalidation.suspend()
        defer { inputInvalidation.resume() }
        let text = manager.stringView.string
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location,
              isScalarBoundary(range.location, in: text),
              isScalarBoundary(range.location + range.length, in: text) else { return nil }
        if range.length == 0 && content.length == 0 {
            didCommit(contentRevision)
            return contentRevision
        }
        let replacement = NSAttributedString(attributedString: content)
        guard let edit = LineEditTransaction.replace(in: manager, range: range, with: replacement.string) else { return nil }
        snapshot.replaceCharacters(in: range, with: replacement)
        let revision = UUID()
        contentRevision = revision
        let affected = edit.lineChanges.editedLines.union(edit.lineChanges.removedLines)
        let ids = Set(affected.map(\.id))
        for id in ids { controllers.removeValue(forKey: id)?.invalidate() }
        controllerOrder.removeAll { ids.contains($0) }
        visibleLayout = nil
        didCommit(revision)
        scheduleAccessibilityValueChanged()
        noteInputCoordinatesChanged()
        needsDisplay = true
        updateViewport()
        return revision
    }

    /// A host must disconnect its input context before releasing this permit.
    func claimInputMutation() -> InputMutationPermit? {
        guard !isRetired, inputMutationPermit == nil, inputMutationDepth == 0 else { return nil }
        let permit = InputMutationPermit()
        inputMutationPermit = permit
        return permit
    }

    @discardableResult
    func releaseInputMutation(_ permit: InputMutationPermit) -> Bool {
        guard inputMutationPermit === permit, inputMutationDepth == 0 else { return false }
        inputMutationPermit = nil
        inputMutationAuthority = nil
        return true
    }

    private func allowsMutation(with permit: InputMutationPermit?, transaction: InputMutationTransaction?) -> Bool {
        guard !isRetired, permitsMutation(with: permit) else { return false }
        if inputMutationPermit != nil { return transaction != nil && activeInputTransaction === transaction }
        return true
    }

    /// Call on the main thread after the context client has been detached.
    func releaseInputMutationWhenIdle(_ permit: InputMutationPermit) {
        guard inputMutationPermit === permit else { return }
        if inputMutationDepth == 0 { _ = releaseInputMutation(permit) }
        else { pendingInputPermitRelease = permit }
    }

    func permitsMutation(with permit: InputMutationPermit?) -> Bool {
        guard !isRetired else { return false }
        if let owner = inputMutationPermit { return owner === permit }
        return permit == nil
    }

    /// A permit belongs to exactly one session for its entire lifetime.
    func bindInputSession(to permit: InputMutationPermit?) -> InputMutationAuthority? {
        guard !isRetired else { return nil }
        guard let permit = permit else { return inputMutationPermit == nil ? InputMutationAuthority() : nil }
        guard inputMutationPermit === permit, !permit.hasSession else { return nil }
        permit.hasSession = true
        let authority = InputMutationAuthority()
        inputMutationAuthority = authority
        return authority
    }

    /// Keeps ownership stable through synchronous layout and change callbacks.
    func beginInputMutation(with permit: InputMutationPermit?, authority: InputMutationAuthority) -> InputMutationTransaction? {
        guard inputMutationDepth == 0, permitsMutation(with: permit) else { return nil }
        if inputMutationPermit != nil && inputMutationAuthority !== authority { return nil }
        let transaction = InputMutationTransaction()
        activeInputTransaction = transaction
        inputMutationDepth += 1
        inputInvalidation.suspend()
        return transaction
    }

    func endInputMutation(_ transaction: InputMutationTransaction) {
        precondition(inputMutationDepth == 1 && activeInputTransaction === transaction)
        activeInputTransaction = nil
        inputMutationDepth -= 1
        if let permit = pendingInputPermitRelease {
            pendingInputPermitRelease = nil
            _ = releaseInputMutation(permit)
        }
        inputInvalidation.resume()
    }

    /// Builds an immutable candidate using two full document copies. Callers
    /// should only request one when a committed-edit owner needs to validate it.
    func candidateContent(replacing range: NSRange, with replacement: NSAttributedString) -> NSAttributedString {
        let candidate = NSMutableAttributedString(attributedString: snapshot)
        candidate.replaceCharacters(in: range, with: replacement)
        return NSAttributedString(attributedString: candidate)
    }

    /// The caller must validate this UTF-16 range against the current document.
    func attributedContent(in range: NSRange) -> NSAttributedString {
        snapshot.attributedSubstring(from: range)
    }

    private func isScalarBoundary(_ offset: Int, in text: NSString) -> Bool {
        guard offset > 0 && offset < text.length else { return true }
        let previous = text.character(at: offset - 1)
        let next = text.character(at: offset)
        return !(0xD800...0xDBFF).contains(previous) || !(0xDC00...0xDFFF).contains(next)
    }

    init(snapshot: NSAttributedString, fallbackHeight: CGFloat,
         inputInvalidation: InputInvalidationDelivery = InputInvalidationDelivery(),
         viewportRecoveryScheduler: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }, viewportRecoveryClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        precondition(fallbackHeight.isFinite && fallbackHeight > 0)
        self.snapshot = NSMutableAttributedString(attributedString: snapshot)
        self.inputInvalidation = inputInvalidation
        self.viewportRecoveryScheduler = viewportRecoveryScheduler
        self.viewportRecoveryClock = viewportRecoveryClock
        self.fallbackHeight = fallbackHeight
        self.manager = LineManager(stringView: StringView(string: snapshot.string))
        super.init(frame: .zero)
        resetLayout(width: 0)
    }

    public required init?(coder: NSCoder) { nil }

    deinit {
        if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        guard !isRetired else { return }
        if let window = window {
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.noteInputCoordinatesChanged()
                })
            }
        }
        noteInputCoordinatesChanged()
    }

    /// The owner also calls this when an ancestor moves inside a stationary window.
    func noteInputCoordinatesChanged() {
        guard !isRetired else { return }
        if !updatingViewport {
            let needsRecovery = viewportRetryExhausted
            resetViewportRecovery()
            if needsRecovery {
                pendingViewportUpdate = true
                inputInvalidation.suspend()
                if !scheduleViewportUpdate() { inputInvalidation.resume() }
            }
        }
        inputGeometryRevision = UUID()
        inputInvalidation.invalidate()
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
        boundsObserver = nil
        guard !isRetired else { return }
        if let clip = enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                                     object: clip, queue: .main) { [weak self] _ in
                self?.noteInputCoordinatesChanged()
                self?.updateViewport()
            }
        }
        noteInputCoordinatesChanged()
        updateViewport()
    }

    public override func layout() {
        super.layout()
        updateViewport()
    }

    /// Runs a single input step with one budget shared by synchronous bounds
    /// notifications and nested layout. An incomplete step may schedule one
    /// separately budgeted geometry recovery; it never replays the input.
    func withBoundedViewportWork<T>(_ budget: PreparedInputViewportWorkBudget,
                                    scheduleRecovery: Bool = true, _ body: () -> T) -> T? {
        guard !isRetired, !updatingViewport, boundedViewportBudget == nil,
              !pendingViewportUpdate, !viewportUpdateScheduled, !viewportRetryExhausted,
              !viewportRecoveryScheduled, let clip = enclosingScrollView?.contentView,
              clip.bounds.width == layoutWidth, budget.check() else { return nil }
        let initialBounds = clip.bounds
        boundedViewportBudget = budget
        defer {
            boundedViewportBudget = nil
            if (budget.exhausted && clip.bounds != initialBounds) || pendingViewportUpdate || visibleLayout == nil {
                pendingViewportUpdate = false
                boundedAbortClip = clip
                boundedAbortBounds = clip.bounds
                boundedAbortContentRevision = contentRevision
                boundedAbortGeneration = UUID()
                visibleLayout = nil
                if scheduleRecovery { scheduleBoundedViewportRecovery(clip: clip) }
            }
        }
        return body()
    }

    /// At most one recovery runs for each failed step. A failed recovery leaves
    /// layout unavailable until an independent viewport or content change.
    private func scheduleBoundedViewportRecovery(clip: NSClipView) {
        let generation = boundedAbortGeneration
        let bounds = clip.bounds
        let revision = contentRevision
        viewportRecoveryScheduler(0) { [weak self, weak clip] in
            guard let self = self, let clip = clip, !self.isRetired,
                  self.boundedAbortGeneration == generation, self.boundedAbortClip === clip,
                  self.boundedAbortBounds == bounds, clip.bounds == bounds,
                  self.contentRevision == revision, self.enclosingScrollView?.contentView === clip,
                  let budget = PreparedInputViewportWorkBudget(clock: self.viewportRecoveryClock, timeLimit: 0.016) else { return }
            _ = self.withBoundedViewportWork(budget, scheduleRecovery: false) {
                self.updateViewport()
            }
            if self.boundedAbortGeneration == generation,
               self.visibleLayout?.isComplete == true, self.visibleLayout?.viewport == clip.bounds {
                self.boundedAbortClip = nil
                self.boundedAbortBounds = nil
                self.boundedAbortContentRevision = nil
                self.boundedAbortGeneration = UUID()
            }
        }
    }

    /// Resolves against the clip bounds, never the dirty drawing rectangle.
    func updateViewport() {
        guard !isRetired else { return }
        if updatingViewport {
            let clip = enclosingScrollView?.contentView
            if clip !== updatingClip || clip?.bounds != updatingBounds || contentRevision != updatingContentRevision {
                pendingViewportUpdate = true
            }
            return
        }
        guard let clip = enclosingScrollView?.contentView else { return }
        if boundedViewportBudget == nil, boundedAbortBounds != nil {
            guard clip !== boundedAbortClip || clip.bounds != boundedAbortBounds ||
                    contentRevision != boundedAbortContentRevision else { return }
            boundedAbortClip = nil
            boundedAbortBounds = nil
            boundedAbortContentRevision = nil
            boundedAbortGeneration = UUID()
        }
        if viewportRetryExhausted {
            guard clip !== exhaustedClip || clip.bounds != exhaustedBounds || contentRevision != exhaustedContentRevision else { return }
            resetViewportRecovery()
        }
        guard clip.bounds.width.isFinite, clip.bounds.width > 0,
              clip.bounds.height.isFinite, clip.bounds.height > 0 else { return }
        let previousGeometry = inputLayoutSignature()
        inputInvalidation.suspend()
        updatingViewport = true
        updatingContentRevision = contentRevision
        updatingClip = clip
        updatingBounds = clip.bounds
        inputGeometryRevision = UUID()
        defer {
            updatingViewport = false
            updatingContentRevision = nil
            updatingClip = nil
            updatingBounds = nil
            inputGeometryRevision = UUID()
            if isRetired { visibleLayout = nil; pendingViewportUpdate = false }
            if boundedViewportBudget != nil {
                if pendingViewportUpdate { visibleLayout = nil }
                if !isRetired && previousGeometry != inputLayoutSignature() { inputInvalidation.invalidate() }
                inputInvalidation.resume()
            } else {
                if pendingViewportUpdate && viewportRetryCount >= 3 {
                    pendingViewportUpdate = false
                    viewportRetryExhausted = true
                    exhaustedClip = clip
                    exhaustedBounds = clip.bounds
                    exhaustedContentRevision = contentRevision
                    visibleLayout = nil
                    needsLayout = true
                    scheduleViewportRecovery()
                }
                if !isRetired && previousGeometry != inputLayoutSignature() { inputInvalidation.invalidate() }
                if !pendingViewportUpdate || !scheduleViewportUpdate() {
                    if !pendingViewportUpdate {
                        viewportRetryCount = 0
                        if !viewportRetryExhausted { viewportRecoveryDelay = 0.05 }
                    }
                    inputInvalidation.resume()
                }
            }
        }
        let viewportRevision = contentRevision
        let width = clip.bounds.width
        if width != layoutWidth {
            guard boundedViewportBudget == nil else { visibleLayout = nil; return }
            // Rebuild currently scales with document line count; preserving an anchor
            // deep in one wrapped line also typesets that line up to the anchor.
            let anchor = resizeAnchor()
            resetLayout(width: width)
            if let anchor = anchor, let line = manager.visibleLine(containingCharacterAt: anchor.location),
               let controller = controller(for: line) {
                let local = min(line.data.length, max(0, anchor.location - line.location))
                let placements = controller.layout(.toLocation(local))
                let fragment = placements.first { placement in
                    let range = placement.documentRange
                    return range.location <= anchor.location && anchor.location < range.location + range.length
                } ?? placements.last
                let documentY = fragment?.frame.minY ?? line.yPosition
                let size = NSSize(width: width, height: max(clip.bounds.height, manager.contentHeight))
                if frame.size != size { setFrameSize(size) }
                guard !isRetired, contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
                var proposed = clip.bounds
                proposed.origin.y = documentY - anchor.screenY
                clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
                enclosingScrollView?.reflectScrolledClipView(clip)
                guard !isRetired, contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
            }
        }
        // Frame changes and scroll clamping can alter the clip's actual bounds.
        // Re-resolve against those bounds before publishing frames for drawing.
        for _ in 0..<3 {
            guard !isRetired, enclosingScrollView?.contentView === clip, clip.bounds.width == width else {
                visibleLayout = nil
                pendingViewportUpdate = true
                return
            }
            let requested = clip.bounds
            guard boundedViewportBudget?.check() ?? true else { visibleLayout = nil; return }
            guard let result = coordinator.layout(in: requested, budget: boundedViewportBudget) else { visibleLayout = nil; return }
            let size = NSSize(width: width, height: max(clip.bounds.height, manager.contentHeight))
            if frame.size != size { setFrameSize(size) }
            guard !isRetired, contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
            var proposed = clip.bounds
            proposed.origin.y = result.viewport.minY
            let constrained = clip.constrainBoundsRect(proposed)
            if clip.bounds.origin != constrained.origin {
                clip.scroll(to: constrained.origin)
                enclosingScrollView?.reflectScrolledClipView(clip)
                guard !isRetired, contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
            }
            guard !isRetired, enclosingScrollView?.contentView === clip,
                  clip.bounds.width == requested.width, clip.bounds.height == requested.height else {
                visibleLayout = nil
                pendingViewportUpdate = true
                return
            }
            if result.isComplete && clip.bounds.minX == result.viewport.minX &&
                abs(clip.bounds.minY - result.viewport.minY) < 0.01 {
                // AppKit may align a constrained scroll origin by a subpixel.
                // Publish the actual bounds while preserving the old tolerance.
                visibleLayout = ViewportLayoutCoordinator.Result(viewport: clip.bounds,
                    contentOffsetAdjustmentY: clip.bounds.minY - requested.minY, lines: result.lines, isComplete: true)
                trimControllers(keeping: Set(result.lines.map { $0.line.id }))
                needsDisplay = true
                return
            }
            if !result.isComplete { visibleLayout = nil; return }
        }
        visibleLayout = nil
        needsLayout = true
    }

    private func resetViewportRecovery() {
        viewportRetryExhausted = false
        viewportRetryCount = 0
        viewportRecoveryDelay = 0.05
        viewportRecoveryScheduled = false
        viewportRecoveryToken = UUID()
    }

    /// A pathological observer may repeatedly change bounds during layout. Retry
    /// at a bounded rate so a later stable view can recover without a new event.
    private func scheduleViewportRecovery() {
        guard !isRetired, boundedViewportBudget == nil, !viewportRecoveryScheduled else { return }
        viewportRecoveryScheduled = true
        let delay = viewportRecoveryDelay
        let token = UUID()
        viewportRecoveryToken = token
        viewportRecoveryDelay = min(2, delay * 2)
        viewportRecoveryScheduler(delay) { [weak self] in
            guard let self = self, self.viewportRecoveryToken == token else { return }
            self.viewportRecoveryScheduled = false
            guard self.viewportRetryExhausted else { return }
            self.viewportRetryExhausted = false
            self.viewportRetryCount = 0
            self.updateViewport()
        }
    }

    private func scheduleViewportUpdate() -> Bool {
        guard !isRetired, boundedViewportBudget == nil, !viewportUpdateScheduled else { return false }
        viewportUpdateScheduled = true
        viewportRetryCount += 1
        let invalidation = inputInvalidation
        DispatchQueue.main.async { [weak self, invalidation] in
            defer { invalidation.resume() }
            guard let self = self else { return }
            self.viewportUpdateScheduled = false
            guard self.pendingViewportUpdate else { return }
            self.pendingViewportUpdate = false
            self.updateViewport()
        }
        return true
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard !isRetired else { return }
        super.draw(dirtyRect)
        guard let result = visibleLayout, let context = NSGraphicsContext.current?.cgContext else { return }
        for line in result.lines {
            line.controller.draw(line.placements, in: context)
        }
    }

    private struct InputLayoutSignature: Equatable {
        struct Fragment: Equatable {
            let range: NSRange
            let frame: CGRect
            let textTop: CGFloat
            let textHeight: CGFloat
        }
        struct Line: Equatable {
            let location: Int
            let y: CGFloat
            let height: CGFloat
            let fragments: [Fragment]
        }
        let viewport: CGRect
        let lines: [Line]
    }

    private func inputLayoutSignature() -> InputLayoutSignature? {
        guard let layout = visibleLayout else { return nil }
        return InputLayoutSignature(viewport: layout.viewport, lines: layout.lines.map { line in
            InputLayoutSignature.Line(location: line.line.location, y: line.line.yPosition,
                                      height: line.line.data.lineHeight, fragments: line.placements.map { placement in
                InputLayoutSignature.Fragment(range: placement.documentRange, frame: placement.frame,
                                              textTop: placement.fragment.verticalGeometry.textTop,
                                              textHeight: placement.fragment.baseSize.height)
            })
        })
    }

    private func resizeAnchor() -> (location: Int, screenY: CGFloat)? {
        guard let result = visibleLayout, let first = result.lines.first else { return nil }
        if let placement = first.placements.first {
            return (placement.documentRange.location, placement.frame.minY - result.viewport.minY)
        }
        return (first.line.location, first.line.yPosition - result.viewport.minY)
    }

    private func resetLayout(width: CGFloat) {
        layoutWidth = width
        controllers.removeAll()
        controllerOrder.removeAll()
        manager = LineManager(stringView: StringView(string: snapshot.string))
        manager.estimatedLineHeight = fallbackHeight
        manager.rebuild()
        coordinator = ViewportLayoutCoordinator(manager: manager) { [weak self] line in
            self?.controller(for: line)
        }
        visibleLayout = nil
    }

    private func controller(for line: DocumentLineNode) -> LogicalLineLayoutController? {
        if let controller = controllers[line.id] {
            controllerOrder.removeAll { $0 == line.id }
            controllerOrder.append(line.id)
            return controller
        }
        let range = NSRange(location: line.location, length: line.data.totalLength)
        guard range.location >= 0, range.length >= 0, range.location <= snapshot.length,
              range.length <= snapshot.length - range.location else { return nil }
        let controller = LogicalLineLayoutController(manager: manager, line: line)
        guard controller.prepare(snapshot.attributedSubstring(from: range), width: layoutWidth,
                                 fallbackHeight: fallbackHeight) else { return nil }
        controllers[line.id] = controller
        controllerOrder.append(line.id)
        return controller
    }

    private func trimControllers(keeping visible: Set<DocumentLineNodeID>) {
        while controllers.count > max(cacheLimit, visible.count),
              let index = controllerOrder.firstIndex(where: { !visible.contains($0) }) {
            let id = controllerOrder.remove(at: index)
            controllers.removeValue(forKey: id)
        }
    }
}
#endif
