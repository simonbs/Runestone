#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// Cooperative limits shared by every pass triggered by a single input step.
/// A Core Text operation already in progress cannot be interrupted by the deadline.
final class PreparedInputViewportWorkBudget {
    private let clock: () -> TimeInterval
    private let deadline: TimeInterval
    private let operationLimit: Int
    private var lastTime: TimeInterval
    private var operations = 0
    private var units = 0
    private(set) var exhausted = false

    init?(clock: @escaping () -> TimeInterval, timeLimit: TimeInterval, operationLimit: Int = 80) {
        let now = clock()
        guard now.isFinite, timeLimit.isFinite, timeLimit > 0, timeLimit <= 0.05,
              operationLimit > 0, operationLimit <= 80, (now + timeLimit).isFinite else { return nil }
        self.clock = clock
        self.lastTime = now
        self.deadline = now + timeLimit
        self.operationLimit = operationLimit
    }

    func check() -> Bool {
        guard !exhausted else { return false }
        let now = clock()
        guard now.isFinite, now >= lastTime, now <= deadline else { exhausted = true; return false }
        lastTime = now
        return true
    }

    func consume(_ line: DocumentLineNode) -> Bool {
        let length = line.data.totalLength
        guard check(), operations < operationLimit, length >= 0, length <= 4_096,
              length <= 16_384 - units else { exhausted = true; return false }
        operations += 1
        units += length
        return true
    }
}

/// Performs one conservative viewport step; it never retains an input event.
/// The caller owns admission, cancellation, scheduling and semantic retry.
enum PreparedInputViewportStep {
    enum Outcome: Equatable {
        case progressed
        case boundary
        /// A callout may already have moved the viewport. Never replay an
        /// input event on the basis of this result.
        case unavailable
    }

    static let maximumDelta: CGFloat = 64
    static let maximumViewportDimension: CGFloat = 2_048
    private static let maximumLines = 80
    private static let maximumLineUnits = 4_096
    private static let maximumTotalUnits = 16_384
    private static let neighborAllowance = 16

    /// Requests at most one short scroll using an already complete viewport.
    /// `isCurrent` must check the caller's document revision, selection,
    /// focus, connection and lifetime. It can be called more than once and
    /// must not itself mutate state. Every AppKit callout is followed by a
    /// fresh identity check. A step never fabricates offscreen caret geometry.
    ///
    /// The preflight rejects oversized viewports, long logical lines and large
    /// nearby working sets before scrolling. The cooperative budget also limits
    /// preparations and layout calls, but a Core Text call cannot be preempted,
    /// so the deadline is not a hard wall-clock bound.
    static func perform(in view: ReadOnlyDocumentView, dx: CGFloat, dy: CGFloat,
                        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                        timeLimit: TimeInterval = 0.016, operationLimit: Int = 80,
                        isCurrent: () -> Bool) -> Outcome {
        precondition(Thread.isMainThread)
        guard dx.isFinite, dy.isFinite, abs(dx) <= maximumDelta, abs(dy) <= maximumDelta,
              !view.isRetired, !view.updatingViewport, let window = view.window,
              let scroll = view.enclosingScrollView, let layout = view.visibleLayout,
              layout.isComplete, scroll.documentView === view else { return .unavailable }
        let clip = scroll.contentView
        let initial = clip.bounds
        guard validViewport(initial), layout.viewport == initial else { return .unavailable }
        let initialScreenViewport = window.convertToScreen(clip.convert(initial, to: nil))
        let contentRevision = view.contentRevision
        let selectionRevision = view.inputSelectionRevision
        let geometryRevision = view.inputGeometryRevision

        func identitiesMatch(geometryMustMatch: Bool) -> Bool {
            guard !view.isRetired, !view.updatingViewport, view.window === window,
                  view.enclosingScrollView === scroll, scroll.contentView === clip,
                  scroll.documentView === view, view.contentRevision == contentRevision,
                  view.inputSelectionRevision == selectionRevision,
                  (!geometryMustMatch || view.inputGeometryRevision == geometryRevision),
                  clip.bounds.size == initial.size, validViewport(clip.bounds),
                  window.convertToScreen(clip.convert(clip.bounds, to: nil)) == initialScreenViewport,
                  isCurrent() else { return false }
            return !view.isRetired && !view.updatingViewport && view.window === window &&
                view.enclosingScrollView === scroll && scroll.contentView === clip &&
                scroll.documentView === view && view.contentRevision == contentRevision &&
                view.inputSelectionRevision == selectionRevision &&
                (!geometryMustMatch || view.inputGeometryRevision == geometryRevision) &&
                clip.bounds.size == initial.size && validViewport(clip.bounds) &&
                window.convertToScreen(clip.convert(clip.bounds, to: nil)) == initialScreenViewport
        }

        guard let budget = PreparedInputViewportWorkBudget(clock: clock, timeLimit: timeLimit,
                                                           operationLimit: operationLimit) else { return .unavailable }
        return view.withBoundedViewportWork(budget) { () -> Outcome in
            guard budget.check(), identitiesMatch(geometryMustMatch: true), clip.bounds == initial else { return .unavailable }
            if dx == 0 && dy == 0 { return .boundary }
            var proposed = initial
            proposed.origin.x += dx
            proposed.origin.y += dy
            guard proposed.origin.x.isFinite, proposed.origin.y.isFinite else { return .unavailable }
            let constrained = clip.constrainBoundsRect(proposed)
            guard identitiesMatch(geometryMustMatch: true), clip.bounds == initial,
                  constrained.size == initial.size, validViewport(constrained) else { return .unavailable }
            if constrained.origin == initial.origin { return .boundary }
            guard preflight(view.manager, current: initial, target: constrained, budget: budget),
                  identitiesMatch(geometryMustMatch: true), clip.bounds == initial, budget.check() else { return .unavailable }

            clip.scroll(to: constrained.origin)
            guard budget.check(), identitiesMatch(geometryMustMatch: false) else { return .unavailable }
            scroll.reflectScrolledClipView(clip)
            guard budget.check(), identitiesMatch(geometryMustMatch: false) else { return .unavailable }
            if view.visibleLayout?.viewport != clip.bounds || view.visibleLayout?.isComplete != true {
                view.updateViewport()
            }
            guard budget.check(), identitiesMatch(geometryMustMatch: false), let fresh = view.visibleLayout,
                  fresh.isComplete, fresh.viewport == clip.bounds else { return .unavailable }
            let movedX = abs(clip.bounds.origin.x - initial.origin.x)
            let movedY = abs(clip.bounds.origin.y - initial.origin.y)
            guard movedX.isFinite, movedY.isFinite, movedX <= maximumDelta + 0.01,
                  movedY <= maximumDelta + 0.01,
                  abs(clip.bounds.minX - constrained.minX) < 0.01,
                  abs(clip.bounds.minY - constrained.minY) < 0.01, budget.check() else { return .unavailable }
            return clip.bounds.origin == initial.origin ? .unavailable : .progressed
        } ?? .unavailable
    }

    private static func validViewport(_ bounds: CGRect) -> Bool {
        bounds.origin.x.isFinite && bounds.origin.y.isFinite && bounds.width.isFinite && bounds.height.isFinite &&
            bounds.maxX.isFinite && bounds.maxY.isFinite && bounds.width > 0 && bounds.height > 0 &&
            bounds.width <= maximumViewportDimension && bounds.height <= maximumViewportDimension
    }

    private static func preflight(_ manager: LineManager, current: CGRect, target: CGRect,
                                  budget: PreparedInputViewportWorkBudget) -> Bool {
        let height = manager.contentHeight
        guard height.isFinite, height > 0 else { return false }
        let margin = max(current.height, maximumDelta)
        let low = max(0, min(current.minY, target.minY) - margin)
        let high = min(height, max(current.maxY, target.maxY) + margin)
        guard low.isFinite, high.isFinite, let first = manager.line(containingYOffset: min(low, height)) else { return false }
        var start = first
        for _ in 0..<neighborAllowance {
            guard budget.check() else { return false }
            guard let previous = manager.previousVisibleLine(before: start) else { break }
            guard previous !== start else { return false }
            start = previous
        }
        var currentLine: DocumentLineNode? = start
        var seen = 0
        var units = 0
        var beyond = 0
        while let line = currentLine {
            let length = line.data.totalLength
            guard budget.check(), length >= 0, length <= maximumLineUnits, seen < maximumLines,
                  length <= maximumTotalUnits - units, line.yPosition.isFinite,
                  line.data.lineHeight.isFinite, line.data.lineHeight > 0 else { return false }
            seen += 1
            units += length
            if line.yPosition >= high {
                beyond += 1
                if beyond >= neighborAllowance { return true }
            }
            let next = manager.nextVisibleLine(after: line)
            guard next !== line else { return false }
            currentLine = next
        }
        return true
    }
}
#endif
