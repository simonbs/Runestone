#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// A read-only, wrapping Core Text view of an attributed document snapshot.
///
/// Install this view as an `NSScrollView`'s document view. Supply text with
/// appropriate AppKit font and foreground color attributes. Input, selection,
/// accessibility navigation, and editing are not provided by this view.
public final class ReadOnlyDocumentView: NSView {
    private var snapshot: NSAttributedString
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
        snapshot = NSAttributedString(attributedString: content)
        resetLayout(width: 0)
        needsDisplay = true
        if let scroll = enclosingScrollView {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        updateViewport()
    }

    init(snapshot: NSAttributedString, fallbackHeight: CGFloat) {
        precondition(fallbackHeight.isFinite && fallbackHeight > 0)
        self.snapshot = NSAttributedString(attributedString: snapshot)
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
                var proposed = clip.bounds
                proposed.origin.y = documentY - anchor.screenY
                clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
                enclosingScrollView?.reflectScrolledClipView(clip)
            }
        }
        // Frame changes and scroll clamping can alter the clip's actual bounds.
        // Re-resolve against those bounds before publishing frames for drawing.
        for _ in 0..<3 {
            let requested = clip.bounds
            guard let result = coordinator.layout(in: requested) else { visibleLayout = nil; return }
            let size = NSSize(width: width, height: max(clip.bounds.height, manager.contentHeight))
            if frame.size != size { setFrameSize(size) }
            var proposed = clip.bounds
            proposed.origin.y = result.viewport.minY
            let constrained = clip.constrainBoundsRect(proposed)
            if clip.bounds.origin != constrained.origin {
                clip.scroll(to: constrained.origin)
                enclosingScrollView?.reflectScrolledClipView(clip)
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
