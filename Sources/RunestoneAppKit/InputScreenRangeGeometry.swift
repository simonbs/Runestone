#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Queries only the currently resolved viewport, without typesetting or scrolling.
/// The input host must invalidate its input context when this viewport changes.
enum InputScreenRangeGeometry {
    typealias RangeGeometry = (rect: NSRect, actualRange: NSRange)

    static func firstRect(for range: NSRange, in view: ReadOnlyDocumentView) -> RangeGeometry? {
        let geometryRevision = view.inputGeometryRevision
        let text = view.manager.stringView.string
        guard valid(range, in: text), let (window, layout) = viewport(in: view) else { return nil }
        if range.length == 0 {
            guard let rect = InputScreenCaretGeometry.rect(at: range.location, in: view),
                  stable(view, window: window, layout: layout, revision: geometryRevision) else { return nil }
            return (rect, range)
        }
        guard let line = view.manager.line(containingCharacterAt: range.location),
              let lineLayout = layout.lines.first(where: { $0.line === line }) else { return nil }
        let lineEnd = line.location + line.data.length
        guard range.location < lineEnd else {
            guard let rect = InputScreenCaretGeometry.rect(at: range.location, in: view),
                  stable(view, window: window, layout: layout, revision: geometryRevision) else { return nil }
            return (rect, NSRange(location: range.location, length: 0))
        }
        let local = range.location - line.location
        guard let placement = lineLayout.placements.first(where: {
            $0.fragment.range.location <= local && local < $0.fragment.range.upperBound
        }) else { return nil }
        let fragment = placement.fragment
        // A logical range can occupy disjoint visual areas in bidi text. Return
        // only the first run and never claim hidden wrap whitespace as visible.
        if local >= fragment.visibleRange.upperBound {
            guard let rect = InputScreenCaretGeometry.rect(at: range.location, in: view),
                  stable(view, window: window, layout: layout, revision: geometryRevision) else { return nil }
            return (rect, NSRange(location: range.location, length: 0))
        }
        guard let runs = CTLineGetGlyphRuns(fragment.line) as? [CTRun],
              let run = runs.first(where: {
                  let r = CTRunGetStringRange($0)
                  return r.location <= local && local < r.location + r.length
              }) else { return nil }
        let runRange = CTRunGetStringRange(run)
        let end = min(range.upperBound, lineEnd, line.location + fragment.visibleRange.upperBound,
                      line.location + runRange.location + runRange.length)
        let actual = NSRange(location: range.location, length: end - range.location)
        guard actual.length > 0, valid(actual, in: text) else { return nil }
        guard let bounds = CoreTextRunGeometry.horizontalBounds(of: run) else { return nil }
        let rtl = CTRunGetStatus(run).contains(.rightToLeft)
        let startX = local == runRange.location
            ? (rtl ? bounds.upperBound : bounds.lowerBound)
            : CTLineGetOffsetForStringIndex(fragment.line, local, nil)
        let localEnd = actual.upperBound - line.location
        let endX = localEnd == runRange.location + runRange.length
            ? (rtl ? bounds.lowerBound : bounds.upperBound)
            : CTLineGetOffsetForStringIndex(fragment.line, localEnd, nil)
        let left = max(bounds.lowerBound, min(startX, endX))
        let right = min(bounds.upperBound, max(startX, endX))
        guard left.isFinite, right.isFinite, right > left else { return nil }
        let documentRect = NSRect(x: placement.frame.minX + left,
                                  y: placement.frame.minY + fragment.verticalGeometry.textTop,
                                  width: right - left, height: fragment.baseSize.height)
        guard documentRect.intersects(layout.viewport) else { return nil }
        let result = window.convertToScreen(view.convert(documentRect, to: nil))
        guard stable(view, window: window, layout: layout, revision: geometryRevision) else { return nil }
        return (result, actual)
    }

    static func characterIndex(for screenPoint: NSPoint, in view: ReadOnlyDocumentView) -> Int? {
        characterIndex(for: screenPoint, in: view, requiresRepresentableCaret: false)
    }

    /// Pointer selection cannot retain bidi or wrap affinity in its NSRange.
    static func characterIndexForPointer(for screenPoint: NSPoint, in view: ReadOnlyDocumentView) -> Int? {
        characterIndex(for: screenPoint, in: view, requiresRepresentableCaret: true)
    }

    private static func characterIndex(for screenPoint: NSPoint, in view: ReadOnlyDocumentView,
                                       requiresRepresentableCaret: Bool) -> Int? {
        let geometryRevision = view.inputGeometryRevision
        guard screenPoint.x.isFinite, screenPoint.y.isFinite,
              let (window, layout) = viewport(in: view) else { return nil }
        let point = view.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        guard let index = characterIndex(forDocumentPoint: point, in: view, layout: layout),
              (!requiresRepresentableCaret || PreparedInputVisualMovement.isRepresentablePointerHit(index, documentPoint: point, in: view)),
              stable(view, window: window, layout: layout, revision: geometryRevision) else { return nil }
        return index
    }

    /// Dragging beyond the viewport selects its nearest laid-out edge without
    /// inventing offscreen geometry or starting an unbounded autoscroll loop.
    static func characterIndexForDrag(for screenPoint: NSPoint, in view: ReadOnlyDocumentView) -> Int? {
        characterIndexForDrag(for: screenPoint, in: view, requiresRepresentableCaret: false)
    }

    /// The same drag clamping as above, with pointer-affinity validation.
    static func characterIndexForPointerDrag(for screenPoint: NSPoint, in view: ReadOnlyDocumentView) -> Int? {
        characterIndexForDrag(for: screenPoint, in: view, requiresRepresentableCaret: true)
    }

    private static func characterIndexForDrag(for screenPoint: NSPoint, in view: ReadOnlyDocumentView,
                                              requiresRepresentableCaret: Bool) -> Int? {
        let revision = view.inputGeometryRevision
        guard screenPoint.x.isFinite, screenPoint.y.isFinite,
              let (window, layout) = viewport(in: view),
              layout.viewport.width > 0, layout.viewport.height > 0 else { return nil }
        let point = view.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let viewport = layout.viewport
        let x = min(max(point.x, viewport.minX), viewport.maxX.nextDown)
        let y = min(max(point.y, viewport.minY), viewport.maxY.nextDown)
        // Whitespace below the final visible line maps to that line's edge.
        // Only already prepared, visible lines participate in this operation.
        let spans: [(CGFloat, CGFloat)] = layout.lines.compactMap { item in
            let top = max(viewport.minY, item.line.yPosition)
            let bottom = min(viewport.maxY, item.line.yPosition + item.line.data.lineHeight)
            return top.isFinite && bottom.isFinite && top < bottom ? (top, bottom) : nil
        }
        guard let nearest = spans.min(by: { a, b in
            let aDistance = max(a.0 - y, 0, y - a.1)
            let bDistance = max(b.0 - y, 0, y - b.1)
            return aDistance < bDistance
        }) else { return nil }
        let clampedY = min(max(y, nearest.0), nearest.1.nextDown)
        let clampedPoint = NSPoint(x: x, y: clampedY)
        guard let index = characterIndex(forDocumentPoint: clampedPoint, in: view, layout: layout),
              (!requiresRepresentableCaret || PreparedInputVisualMovement.isRepresentablePointerHit(index, documentPoint: clampedPoint, in: view)),
              stable(view, window: window, layout: layout, revision: revision) else { return nil }
        return index
    }

    private static func characterIndex(forDocumentPoint point: NSPoint, in view: ReadOnlyDocumentView,
                                       layout: ViewportLayoutCoordinator.Result) -> Int? {
        guard layout.viewport.contains(point),
              let lineLayout = layout.lines.first(where: {
                  point.y >= $0.line.yPosition && point.y < $0.line.yPosition + $0.line.data.lineHeight
              }) else { return nil }
        let line = lineLayout.line
        if line.data.length == 0 { return line.location }
        guard let placement = lineLayout.placements.first(where: {
            point.y >= $0.frame.minY && point.y < $0.frame.maxY
        }) else { return nil }
        let fragment = placement.fragment
        let raw = CTLineGetStringIndexForPosition(fragment.line, CGPoint(x: point.x - placement.frame.minX, y: 0))
        guard raw != kCFNotFound else { return nil }
        let local = min(fragment.visibleRange.upperBound, max(fragment.visibleRange.location, raw))
        let text = view.manager.stringView.string
        let candidate = min(line.location + line.data.length, line.location + local)
        guard candidate > 0 && candidate < text.length else { return candidate }
        let cluster = text.rangeOfComposedCharacterSequence(at: candidate)
        guard candidate > cluster.location else { return candidate }
        let start = max(line.location + fragment.visibleRange.location, cluster.location)
        let end = min(line.location + fragment.visibleRange.upperBound, cluster.upperBound)
        guard start < end else { return nil }
        // Enumerate logical edges rather than using a primary bidi caret that
        // may belong to an adjacent directional run.
        var leading: [CGFloat] = []
        var trailing: [(Int, CGFloat)] = []
        CTLineEnumerateCaretOffsets(fragment.line) { x, index, isLeading, _ in
            let documentIndex = line.location + index
            if isLeading && documentIndex == start { leading.append(x) }
            if !isLeading && documentIndex >= start && documentIndex < end { trailing.append((documentIndex, x)) }
        }
        guard let finalIndex = trailing.map(\.0).max() else { return nil }
        let leadingDistance = leading.map { abs(point.x - placement.frame.minX - $0) }.min()
        let trailingDistance = trailing.filter { $0.0 == finalIndex }
            .map { abs(point.x - placement.frame.minX - $0.1) }.min()
        guard let startDistance = leadingDistance, let endDistance = trailingDistance else { return nil }
        return startDistance <= endDistance ? start : end
    }

    private static func viewport(in view: ReadOnlyDocumentView) -> (NSWindow, ViewportLayoutCoordinator.Result)? {
        guard !view.updatingViewport, let window = view.window, let clip = view.enclosingScrollView?.contentView,
              let layout = view.visibleLayout, layout.isComplete, layout.viewport == clip.bounds else { return nil }
        return (window, layout)
    }

    private static func stable(_ view: ReadOnlyDocumentView, window: NSWindow,
                               layout: ViewportLayoutCoordinator.Result, revision: UUID) -> Bool {
        !view.updatingViewport && revision == view.inputGeometryRevision && view.window === window &&
            view.enclosingScrollView?.contentView.bounds == layout.viewport
    }

    private static func valid(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return false }
        func boundary(_ i: Int) -> Bool {
            i == 0 || i == text.length || !(0xD800...0xDBFF).contains(text.character(at: i - 1)) ||
                !(0xDC00...0xDFFF).contains(text.character(at: i))
        }
        return boundary(range.location) && boundary(range.upperBound)
    }
}
#endif
