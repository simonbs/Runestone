#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// A read-only, wrapping Core Text view of an attributed document snapshot.
///
/// Install this view as an `NSScrollView`'s document view. Supply text with
/// appropriate AppKit font and foreground color attributes. Input, selection,
/// accessibility navigation, and interactive editing are not provided by this view.
public final class ReadOnlyDocumentView: NSView {
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
    private(set) var updatingViewport = false
    private var pendingViewportUpdate = false
    private var viewportUpdateScheduled = false
    private var viewportRetryCount = 0
    private var viewportRetryExhausted = false
    private var viewportRecoveryScheduled = false
    private var viewportRecoveryToken = UUID()
    private var viewportRecoveryDelay: TimeInterval = 0.05
    private let viewportRecoveryScheduler: (TimeInterval, @escaping () -> Void) -> Void
    private weak var exhaustedClip: NSClipView?
    private var exhaustedBounds: CGRect?
    private var exhaustedContentRevision: UUID?
    private var updatingContentRevision: UUID?
    private weak var updatingClip: NSClipView?
    private var updatingBounds: CGRect?
    private(set) var visibleLayout: ViewportLayoutCoordinator.Result?

    public override var isFlipped: Bool { true }

    /// Creates a view containing a copy of the supplied attributed string.
    /// Attribute values are not deep-copied and should be treated as immutable.
    public convenience init(content: NSAttributedString) {
        self.init(snapshot: content, fallbackHeight: 16)
    }

    /// A copy of the current document snapshot.
    public var content: NSAttributedString { NSAttributedString(attributedString: snapshot) }

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
        noteInputCoordinatesChanged()
        needsDisplay = true
        updateViewport()
        return revision
    }

    /// A host must disconnect its input context before releasing this permit.
    func claimInputMutation() -> InputMutationPermit? {
        guard inputMutationPermit == nil, inputMutationDepth == 0 else { return nil }
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
        guard permitsMutation(with: permit) else { return false }
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
        if let owner = inputMutationPermit { return owner === permit }
        return permit == nil
    }

    /// A permit belongs to exactly one session for its entire lifetime.
    func bindInputSession(to permit: InputMutationPermit?) -> InputMutationAuthority? {
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
         }) {
        precondition(fallbackHeight.isFinite && fallbackHeight > 0)
        self.snapshot = NSMutableAttributedString(attributedString: snapshot)
        self.inputInvalidation = inputInvalidation
        self.viewportRecoveryScheduler = viewportRecoveryScheduler
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

    /// Resolves against the clip bounds, never the dirty drawing rectangle.
    func updateViewport() {
        if updatingViewport {
            let clip = enclosingScrollView?.contentView
            if clip !== updatingClip || clip?.bounds != updatingBounds || contentRevision != updatingContentRevision {
                pendingViewportUpdate = true
            }
            return
        }
        guard let clip = enclosingScrollView?.contentView else { return }
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
            if previousGeometry != inputLayoutSignature() { inputInvalidation.invalidate() }
            if !pendingViewportUpdate || !scheduleViewportUpdate() {
                if !pendingViewportUpdate {
                    viewportRetryCount = 0
                    if !viewportRetryExhausted { viewportRecoveryDelay = 0.05 }
                }
                inputInvalidation.resume()
            }
        }
        let viewportRevision = contentRevision
        let width = clip.bounds.width
        if width != layoutWidth {
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
                guard contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
                var proposed = clip.bounds
                proposed.origin.y = documentY - anchor.screenY
                clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
                enclosingScrollView?.reflectScrolledClipView(clip)
                guard contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
            }
        }
        // Frame changes and scroll clamping can alter the clip's actual bounds.
        // Re-resolve against those bounds before publishing frames for drawing.
        for _ in 0..<3 {
            guard enclosingScrollView?.contentView === clip, clip.bounds.width == width else {
                visibleLayout = nil
                pendingViewportUpdate = true
                return
            }
            let requested = clip.bounds
            guard let result = coordinator.layout(in: requested) else { visibleLayout = nil; return }
            let size = NSSize(width: width, height: max(clip.bounds.height, manager.contentHeight))
            if frame.size != size { setFrameSize(size) }
            guard contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
            var proposed = clip.bounds
            proposed.origin.y = result.viewport.minY
            let constrained = clip.constrainBoundsRect(proposed)
            if clip.bounds.origin != constrained.origin {
                clip.scroll(to: constrained.origin)
                enclosingScrollView?.reflectScrolledClipView(clip)
                guard contentRevision == viewportRevision else { visibleLayout = nil; needsLayout = true; return }
            }
            guard enclosingScrollView?.contentView === clip,
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
        guard !viewportRecoveryScheduled else { return }
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
        guard !viewportUpdateScheduled else { return false }
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
