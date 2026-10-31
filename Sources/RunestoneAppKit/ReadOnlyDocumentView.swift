#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// A read-only, wrapping Core Text view of an attributed document snapshot.
///
/// Install this view as an `NSScrollView`'s document view. Supply text with
/// appropriate AppKit font and foreground color attributes. Input, selection,
/// accessibility navigation, and interactive editing are not provided by this view.
public final class ReadOnlyDocumentView: NSView {
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
    private var updatingViewport = false
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
    /// time proportional to the size of the document.
    public func setContent(_ content: NSAttributedString) {
        _ = setContentReturningRevision(content)
    }

    /// Publishes the fully installed model before any layout notification can run.
    /// The synchronous hook must only publish matching internal session state.
    @discardableResult
    func setContentReturningRevision(_ content: NSAttributedString, didCommit: (UUID) -> Void = { _ in }) -> UUID {
        snapshot = NSMutableAttributedString(attributedString: content)
        let revision = UUID()
        contentRevision = revision
        resetLayout(width: 0)
        didCommit(revision)
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
    @discardableResult
    public func replaceContent(in range: NSRange, with content: NSAttributedString) -> Bool {
        replaceContentReturningRevision(in: range, with: content) != nil
    }

    /// Publishes the fully installed model before any layout notification can run.
    /// The synchronous hook must only publish matching internal session state.
    func replaceContentReturningRevision(in range: NSRange, with content: NSAttributedString,
                                         didCommit: (UUID) -> Void = { _ in }) -> UUID? {
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
        needsDisplay = true
        updateViewport()
        return revision
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

    init(snapshot: NSAttributedString, fallbackHeight: CGFloat) {
        precondition(fallbackHeight.isFinite && fallbackHeight > 0)
        self.snapshot = NSMutableAttributedString(attributedString: snapshot)
        self.fallbackHeight = fallbackHeight
        self.manager = LineManager(stringView: StringView(string: snapshot.string))
        super.init(frame: .zero)
        resetLayout(width: 0)
    }

    public required init?(coder: NSCoder) { nil }

    deinit {
        if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
        boundsObserver = nil
        if let clip = enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                                     object: clip, queue: .main) { [weak self] _ in
                self?.updateViewport()
            }
        }
        updateViewport()
    }

    public override func layout() {
        super.layout()
        updateViewport()
    }

    /// Resolves against the clip bounds, never the dirty drawing rectangle.
    func updateViewport() {
        guard !updatingViewport, let clip = enclosingScrollView?.contentView,
              clip.bounds.width.isFinite, clip.bounds.width > 0,
              clip.bounds.height.isFinite, clip.bounds.height > 0 else { return }
        updatingViewport = true
        defer { updatingViewport = false }
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
            if result.isComplete && abs(clip.bounds.minY - result.viewport.minY) < 0.01 {
                visibleLayout = result
                trimControllers(keeping: Set(result.lines.map { $0.line.id }))
                needsDisplay = true
                return
            }
            if !result.isComplete { visibleLayout = nil; return }
        }
        visibleLayout = nil
        needsLayout = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let result = visibleLayout, let context = NSGraphicsContext.current?.cgContext else { return }
        for line in result.lines {
            line.controller.draw(line.placements, in: context)
        }
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
