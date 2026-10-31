#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Computes navigation only from a fully resolved, current viewport. It does
/// not lay out, scroll, mutate a selection, or retain any document state.
enum PreparedInputVisualMovement {
    enum Direction { case up, down }
    enum Edge { case beginning, end }
    enum HorizontalDirection { case left, right }
    enum HorizontalResult: Equatable {
        case moved(Int)
        case boundary
        case unavailable
    }

    struct Destination {
        let location: Int
        /// Preserve this screen coordinate across consecutive vertical moves.
        let preferredScreenX: CGFloat
    }

    private struct Row {
        let line: ViewportLayoutCoordinator.LineLayout
        let placement: LogicalLineLayoutController.Placement?
        let frame: CGRect
    }

    private struct Context {
        let window: NSWindow
        let clip: NSClipView
        let layout: ViewportLayoutCoordinator.Result
        let geometryRevision: UUID
        let contentRevision: UUID
    }

    /// Move to the adjacent currently visible visual fragment, preserving the
    /// supplied horizontal coordinate even when an intermediate line is short.
    /// nil means geometry is unavailable, stale, or outside the viewport; the
    /// caller must not infer a logical-column move or replay against new state.
    static func vertical(from location: Int, direction: Direction, preferredScreenX: CGFloat?,
                         in view: ReadOnlyDocumentView) -> Destination? {
        guard let context = context(in: view),
              let caret = InputScreenCaretGeometry.rect(at: location, in: view),
              let source = sourceRow(caret: caret, context: context, view: view),
              unambiguousVerticalCaret(location, caret: caret, row: source, context: context, view: view) else { return nil }
        let rows = visibleRows(in: context.layout)
        guard let index = rows.firstIndex(where: { sameRow($0, source) }) else { return nil }
        let next = direction == .up ? index - 1 : index + 1
        guard rows.indices.contains(next) else { return nil }
        let preferredX = preferredScreenX ?? caret.midX
        guard preferredX.isFinite, let target = hit(row: rows[next], screenX: preferredX,
                                                   context: context, view: view),
              let targetCaret = InputScreenCaretGeometry.rect(at: target, in: view),
              let resolvedRow = sourceRow(caret: targetCaret, context: context, view: view),
              sameRow(resolvedRow, rows[next]),
              unambiguousVerticalCaret(target, caret: targetCaret, row: resolvedRow, context: context, view: view),
              stable(context, view: view) else { return nil }
        return Destination(location: target, preferredScreenX: preferredX)
    }

    /// True only when the adjacent visual row is not in the current complete
    /// viewport. An existing but ambiguous/clipped target must not trigger an
    /// unrelated scroll as a substitute for resolving affinity.
    static func verticalNeedsViewportStep(from location: Int, direction: Direction,
                                          in view: ReadOnlyDocumentView) -> Bool {
        guard let context = context(in: view),
              let caret = InputScreenCaretGeometry.rect(at: location, in: view),
              let source = sourceRow(caret: caret, context: context, view: view),
              unambiguousVerticalCaret(location, caret: caret, row: source, context: context, view: view) else { return false }
        let rows = visibleRows(in: context.layout)
        guard let index = rows.firstIndex(where: { sameRow($0, source) }) else { return false }
        let next = direction == .up ? index - 1 : index + 1
        return !rows.indices.contains(next) && stable(context, view: view)
    }

    /// Move to the next visual caret edge only when Core Text gives one
    /// unambiguous grapheme boundary for both source and destination. A bidi
    /// boundary with multiple affinities cannot be represented by an NSRange;
    /// reject it rather than choosing an arbitrary logical edge.
    static func horizontal(from location: Int, direction: HorizontalDirection,
                           in view: ReadOnlyDocumentView) -> HorizontalResult {
        guard let context = context(in: view),
              let caret = InputScreenCaretGeometry.rect(at: location, in: view),
              let source = sourceRow(caret: caret, context: context, view: view),
              validBoundary(location, in: view.manager.stringView.string) else { return .unavailable }
        // Collapsed wrap whitespace can contain several distinct UTF-16
        // positions at the same visual x. Those positions are representable
        // individually even though the shared end-of-fragment boundary is not.
        if let result = hiddenTailStep(from: location, direction: direction, source: source,
                                       context: context, view: view) { return result }
        guard let sourceEdges = horizontalEdges(for: source, in: view),
              let sourceGroup = group(at: caretDocumentX(caret, context: context, view: view), in: sourceEdges),
              uniqueTarget(in: sourceGroup) == location else { return .unavailable }
        let x = sourceGroup[0].x
        let adjacent = sourceEdges.filter { direction == .left ? $0.x < x - horizontalTolerance : $0.x > x + horizontalTolerance }
        if let nextX = direction == .left ? adjacent.map(\.x).max() : adjacent.map(\.x).min() {
            guard let targetGroup = group(at: nextX, in: adjacent),
                  let target = uniqueTarget(in: targetGroup),
                  !isSharedWrapBoundary(target, in: source),
                  isVisible(x: nextX, row: source, context: context),
                  stable(context, view: view) else { return .unavailable }
            return .moved(target)
        }
        return crossLine(from: source, direction: direction, context: context, view: view)
    }

    /// Return the visual left or right edge of the current visible fragment.
    /// If either edge is clipped, return nil rather than guessing the unseen
    /// destination. Caret affinity follows the existing primary-caret geometry.
    static func lineEdge(from location: Int, edge: Edge, in view: ReadOnlyDocumentView) -> Int? {
        guard let context = context(in: view),
              let caret = InputScreenCaretGeometry.rect(at: location, in: view),
              let row = sourceRow(caret: caret, context: context, view: view) else { return nil }
        guard let placement = row.placement else {
            return stable(context, view: view) ? row.line.line.location : nil
        }
        guard let (left, right) = caretBounds(of: placement),
              left >= context.layout.viewport.minX, right < context.layout.viewport.maxX else { return nil }
        let x = edge == .beginning ? left : right
        let top = max(row.frame.minY, context.layout.viewport.minY)
        let bottom = min(row.frame.maxY, context.layout.viewport.maxY)
        guard top < bottom else { return nil }
        let y = (top + bottom) / 2
        let point = context.window.convertPoint(toScreen: view.convert(NSPoint(x: x, y: y), to: nil))
        guard let result = InputScreenRangeGeometry.characterIndex(for: point, in: view),
              stable(context, view: view) else { return nil }
        return result
    }

    /// Return the logical start or end of the current visual fragment rather
    /// than its left or right edge. The visible end is used when wrap-hidden
    /// whitespace follows; this keeps the destination on the rendered row.
    /// Ambiguous bidi/wrap-boundary caret affinity is not modeled here.
    static func logicalLineEdge(from location: Int, edge: Edge, in view: ReadOnlyDocumentView) -> Int? {
        guard let context = context(in: view),
              validBoundary(location, in: view.manager.stringView.string),
              let caret = InputScreenCaretGeometry.rect(at: location, in: view),
              let row = sourceRow(caret: caret, context: context, view: view) else { return nil }
        let target: Int
        if let placement = row.placement {
            let range = placement.fragment.visibleRange
            guard range.location >= 0, range.length >= 0, range.location <= Int.max - range.length,
                  row.line.line.location <= Int.max - range.upperBound else { return nil }
            // The Core Text fragment may include a terminal CR/LF delimiter.
            // A line-end command stops before that delimiter, not after it.
            let contentEnd = min(range.upperBound, row.line.line.data.length)
            guard range.location <= contentEnd else { return nil }
            target = row.line.line.location + (edge == .beginning ? range.location : contentEnd)
        } else {
            target = row.line.line.location
        }
        let text = view.manager.stringView.string
        guard validBoundary(target, in: text), stable(context, view: view) else { return nil }
        return target
    }

    /// At a soft wrap the same insertion offset denotes the end of one row
    /// and the start of another. The public range has no affinity to choose.
    private static func isSharedWrapBoundary(_ offset: Int, in row: Row) -> Bool {
        guard let placement = row.placement else { return false }
        let line = row.line.line
        let range = placement.fragment.range
        guard range.location >= 0, range.length >= 0, range.location <= Int.max - range.length,
              line.location <= Int.max - range.upperBound else { return true }
        return (range.location > 0 && offset == line.location + range.location) ||
            (range.upperBound < line.data.length && offset == line.location + range.upperBound)
    }

    /// Only move one complete hidden grapheme at a time; never jump across
    /// hidden content or enter the shared boundary of the next visual row.
    private static func hiddenTailStep(from location: Int, direction: HorizontalDirection, source: Row,
                                       context: Context, view: ReadOnlyDocumentView) -> HorizontalResult? {
        guard let placement = source.placement, placement.fragment.hiddenLength > 0 else { return nil }
        let line = source.line.line
        let visible = placement.fragment.visibleRange
        let range = placement.fragment.range
        guard visible.location >= 0, visible.length >= 0, range.location >= 0, range.length >= 0,
              visible.location <= Int.max - visible.length, range.location <= Int.max - range.length,
              line.location <= Int.max - range.upperBound else { return .unavailable }
        let start = line.location + visible.upperBound
        let end = line.location + min(range.upperBound, line.data.length)
        guard start <= location && location < end else { return nil }
        guard containsRightToLeftRun(source) == false else { return .unavailable }
        let text = view.manager.stringView.string
        let target: Int
        switch direction {
        case .left:
            guard location > start else { return nil }
            let cluster = text.rangeOfComposedCharacterSequence(at: location - 1)
            guard cluster.upperBound == location, cluster.location >= start else { return .unavailable }
            target = cluster.location
        case .right:
            let cluster = text.rangeOfComposedCharacterSequence(at: location)
            guard cluster.location == location, cluster.upperBound <= end else { return .unavailable }
            target = cluster.upperBound
        }
        guard validBoundary(target, in: text), !isSharedWrapBoundary(target, in: source),
              stable(context, view: view) else { return .unavailable }
        return .moved(target)
    }

    private static let horizontalTolerance: CGFloat = 0.01

    private struct HorizontalEdge {
        let x: CGFloat
        let target: Int
        let ambiguous: Bool
    }

    /// Core Text enumerates logical leading/trailing character edges in visual
    /// order. Collapse edges inside the same composed character to its external
    /// boundaries; an affinity is ambiguous when its primary and secondary
    /// offsets differ. Keep ambiguous edges in the ordering so we never skip
    /// over one to reach a farther, apparently unambiguous position.
    private static func horizontalEdges(for row: Row, in view: ReadOnlyDocumentView) -> [HorizontalEdge]? {
        let text = view.manager.stringView.string
        guard let placement = row.placement else {
            return [HorizontalEdge(x: row.frame.minX, target: row.line.line.location, ambiguous: false)]
        }
        let lineStart = row.line.line.location
        let range = placement.fragment.visibleRange
        guard range.location >= 0, range.length > 0, range.location <= Int.max - range.length,
              lineStart <= Int.max - range.upperBound else { return nil }
        // Prepared Core Text fragments include the line delimiter, but those
        // zero-width glyph edges are not caret positions within this row.
        let contentEnd = min(range.upperBound, row.line.line.data.length)
        guard range.location < contentEnd else { return nil }
        let documentStart = lineStart + range.location
        let documentEnd = lineStart + contentEnd
        guard documentStart >= 0, documentEnd <= text.length else { return nil }
        var result: [HorizontalEdge] = []
        CTLineEnumerateCaretOffsets(placement.fragment.line) { offset, index, leading, _ in
            guard offset.isFinite, index >= range.location, index < contentEnd else { return }
            let absolute = lineStart + index
            guard absolute >= 0, absolute < text.length else { return }
            let cluster = text.rangeOfComposedCharacterSequence(at: absolute)
            guard cluster.location >= documentStart, cluster.upperBound <= documentEnd else { return }
            let target = leading ? cluster.location : cluster.upperBound
            guard validBoundary(target, in: text) else { return }
            var secondary: CGFloat = 0
            let primary = CTLineGetOffsetForStringIndex(placement.fragment.line, target - lineStart, &secondary)
            guard primary.isFinite, secondary.isFinite,
                  abs(primary - offset) <= horizontalTolerance || abs(secondary - offset) <= horizontalTolerance else { return }
            result.append(HorizontalEdge(x: placement.frame.minX + offset, target: target,
                                         ambiguous: abs(primary - secondary) > horizontalTolerance))
        }
        return result.isEmpty ? nil : result
    }

    private static func validBoundary(_ offset: Int, in text: NSString) -> Bool {
        guard offset >= 0, offset <= text.length else { return false }
        guard offset > 0, offset < text.length else { return true }
        guard !(text.character(at: offset - 1) == 0x0D && text.character(at: offset) == 0x0A) else { return false }
        return text.rangeOfComposedCharacterSequence(at: offset).location == offset
    }

    private static func caretDocumentX(_ rect: NSRect, context: Context, view: ReadOnlyDocumentView) -> CGFloat {
        view.convert(context.window.convertFromScreen(rect), from: nil).minX
    }

    private static func group(at x: CGFloat, in edges: [HorizontalEdge]) -> [HorizontalEdge]? {
        guard x.isFinite else { return nil }
        let group = edges.filter { abs($0.x - x) <= horizontalTolerance }
        return group.isEmpty ? nil : group
    }

    private static func uniqueTarget(in edges: [HorizontalEdge]) -> Int? {
        guard let first = edges.first, !edges.contains(where: { $0.ambiguous || $0.target != first.target }) else { return nil }
        return first.target
    }

    /// A vertical move stores only a UTF-16 offset. Verify that the offset
    /// resolves to exactly one visible caret on this row; hidden wrap tails,
    /// shared wrap boundaries, and bidi alternatives need an affinity instead.
    private static func unambiguousVerticalCaret(_ offset: Int, caret: NSRect, row: Row,
                                                 context: Context, view: ReadOnlyDocumentView) -> Bool {
        guard validBoundary(offset, in: view.manager.stringView.string),
              !isSharedWrapBoundary(offset, in: row) else { return false }
        if let placement = row.placement, placement.fragment.hiddenLength > 0 {
            let visible = placement.fragment.visibleRange
            guard visible.location >= 0, visible.length >= 0,
                  visible.location <= Int.max - visible.length,
                  row.line.line.location <= Int.max - visible.upperBound,
                  offset < row.line.line.location + visible.upperBound else { return false }
        }
        guard let edges = horizontalEdges(for: row, in: view),
              let candidates = group(at: caretDocumentX(caret, context: context, view: view), in: edges),
              uniqueTarget(in: candidates) == offset else { return false }
        return stable(context, view: view)
    }

    /// The pointer's hit row must agree with the row that a stored offset
    /// will later draw on. The hit point is in document coordinates and must
    /// already have been clamped by the drag hit test when appropriate.
    static func isRepresentablePointerHit(_ offset: Int, documentPoint: NSPoint,
                                          in view: ReadOnlyDocumentView) -> Bool {
        guard documentPoint.x.isFinite, documentPoint.y.isFinite,
              let context = context(in: view), context.layout.viewport.contains(documentPoint),
              let hitRow = visibleRows(in: context.layout).first(where: {
                  documentPoint.y >= $0.frame.minY && documentPoint.y < $0.frame.maxY
              }), let caret = InputScreenCaretGeometry.rect(at: offset, in: view),
              let resolvedRow = sourceRow(caret: caret, context: context, view: view),
              sameRow(hitRow, resolvedRow),
              unambiguousVerticalCaret(offset, caret: caret, row: resolvedRow, context: context, view: view) else { return false }
        return stable(context, view: view)
    }

    private static func isVisible(x: CGFloat, row: Row, context: Context) -> Bool {
        x.isFinite && x >= context.layout.viewport.minX && x < context.layout.viewport.maxX &&
            row.frame.maxY > context.layout.viewport.minY && row.frame.minY < context.layout.viewport.maxY
    }

    /// Crossing a hard line boundary is safe only if the adjacent logical
    /// line and its boundary fragment are already visible. A wrap transition
    /// would require caret affinity, which this selection model does not hold.
    private static func crossLine(from source: Row, direction: HorizontalDirection,
                                  context: Context, view: ReadOnlyDocumentView) -> HorizontalResult {
        // Visual left/right does not identify the adjacent logical line for
        // an RTL or mixed-direction row. Until selection carries affinity and
        // paragraph direction, never invent a cross-row transition for it.
        guard containsRightToLeftRun(source) == false else { return .unavailable }
        if let placement = source.placement {
            let range = placement.fragment.range
            if direction == .left && range.location != 0 { return .unavailable }
            if direction == .right && range.upperBound < source.line.line.data.length { return .unavailable }
        }
        let neighbor = direction == .left
            ? view.manager.previousVisibleLine(before: source.line.line)
            : view.manager.nextVisibleLine(after: source.line.line)
        guard let neighbor = neighbor else { return stable(context, view: view) ? .boundary : .unavailable }
        let rows = visibleRows(in: context.layout)
        guard let index = rows.firstIndex(where: { sameRow($0, source) }) else { return .unavailable }
        let next = direction == .left ? index - 1 : index + 1
        guard rows.indices.contains(next), rows[next].line.line === neighbor else { return .unavailable }
        let targetRow = rows[next]
        guard containsRightToLeftRun(targetRow) == false else { return .unavailable }
        if let placement = targetRow.placement {
            let range = placement.fragment.range
            if direction == .left && range.upperBound < neighbor.data.length { return .unavailable }
            if direction == .right && range.location != 0 { return .unavailable }
        }
        guard let edges = horizontalEdges(for: targetRow, in: view),
              let x = direction == .left ? edges.map(\.x).max() : edges.map(\.x).min(),
              let targetGroup = group(at: x, in: edges), let target = uniqueTarget(in: targetGroup),
              isVisible(x: x, row: targetRow, context: context), stable(context, view: view) else { return .unavailable }
        return .moved(target)
    }

    private static func containsRightToLeftRun(_ row: Row) -> Bool? {
        guard let placement = row.placement else { return false }
        guard let runs = CTLineGetGlyphRuns(placement.fragment.line) as? [CTRun] else { return nil }
        return runs.contains { CTRunGetStatus($0).contains(.rightToLeft) }
    }

    private static func context(in view: ReadOnlyDocumentView) -> Context? {
        guard !view.isRetired, !view.updatingViewport, let window = view.window,
              let clip = view.enclosingScrollView?.contentView, let layout = view.visibleLayout,
              layout.isComplete, layout.viewport == clip.bounds,
              layout.viewport.minX.isFinite, layout.viewport.minY.isFinite,
              layout.viewport.maxX.isFinite, layout.viewport.maxY.isFinite,
              layout.viewport.width > 0, layout.viewport.height > 0 else { return nil }
        return Context(window: window, clip: clip, layout: layout,
                       geometryRevision: view.inputGeometryRevision, contentRevision: view.contentRevision)
    }

    private static func stable(_ context: Context, view: ReadOnlyDocumentView) -> Bool {
        !view.isRetired && !view.updatingViewport && view.window === context.window &&
            view.enclosingScrollView?.contentView === context.clip && context.clip.bounds == context.layout.viewport &&
            view.inputGeometryRevision == context.geometryRevision && view.contentRevision == context.contentRevision
    }

    private static func visibleRows(in layout: ViewportLayoutCoordinator.Result) -> [Row] {
        var rows: [Row] = []
        for line in layout.lines {
            if line.line.data.length == 0 {
                let frame = CGRect(x: 0, y: line.line.yPosition, width: 1, height: line.line.data.lineHeight)
                if frame.minY.isFinite, frame.height.isFinite, frame.height > 0,
                   frame.maxY > layout.viewport.minY, frame.minY < layout.viewport.maxY {
                    rows.append(Row(line: line, placement: nil, frame: frame))
                }
            } else {
                for placement in line.placements where placement.frame.height > 0 &&
                    placement.frame.maxY > layout.viewport.minY && placement.frame.minY < layout.viewport.maxY {
                    rows.append(Row(line: line, placement: placement, frame: placement.frame))
                }
            }
        }
        return rows.sorted { $0.frame.minY < $1.frame.minY }
    }

    private static func sourceRow(caret: NSRect, context: Context, view: ReadOnlyDocumentView) -> Row? {
        let documentRect = view.convert(context.window.convertFromScreen(caret), from: nil)
        guard documentRect.midY.isFinite else { return nil }
        return visibleRows(in: context.layout).first {
            documentRect.midY >= $0.frame.minY && documentRect.midY < $0.frame.maxY
        }
    }

    private static func sameRow(_ lhs: Row, _ rhs: Row) -> Bool {
        lhs.line.line === rhs.line.line && lhs.placement?.fragment.id == rhs.placement?.fragment.id
    }

    private static func hit(row: Row, screenX: CGFloat, context: Context, view: ReadOnlyDocumentView) -> Int? {
        let top = max(row.frame.minY, context.layout.viewport.minY)
        let bottom = min(row.frame.maxY, context.layout.viewport.maxY)
        guard top.isFinite, bottom.isFinite, top < bottom else { return nil }
        let sample = context.window.convertPoint(toScreen: view.convert(NSPoint(x: context.layout.viewport.midX,
                                                                                  y: (top + bottom) / 2), to: nil))
        let point = NSPoint(x: screenX, y: sample.y)
        let documentPoint = view.convert(context.window.convertPoint(fromScreen: point), from: nil)
        guard context.layout.viewport.contains(documentPoint) else { return nil }
        guard let placement = row.placement else { return row.line.line.location }
        guard let (left, right) = caretBounds(of: placement) else { return nil }
        // A short visual row ends before the preferred x. Hit its nearest
        // visual caret edge, but retain the original x for the following move.
        let x = min(right, max(left, documentPoint.x))
        guard x >= context.layout.viewport.minX, x < context.layout.viewport.maxX else { return nil }
        let target = context.window.convertPoint(toScreen: view.convert(NSPoint(x: x, y: (top + bottom) / 2), to: nil))
        return InputScreenRangeGeometry.characterIndex(for: target, in: view)
    }

    private static func caretBounds(of placement: LogicalLineLayoutController.Placement) -> (CGFloat, CGFloat)? {
        var minimum: CGFloat?
        var maximum: CGFloat?
        CTLineEnumerateCaretOffsets(placement.fragment.line) { x, _, _, _ in
            let coordinate = placement.frame.minX + x
            guard coordinate.isFinite else { return }
            minimum = min(minimum ?? coordinate, coordinate)
            maximum = max(maximum ?? coordinate, coordinate)
        }
        guard let minimum = minimum, let maximum = maximum else { return nil }
        return (minimum, maximum)
    }
}
#endif
