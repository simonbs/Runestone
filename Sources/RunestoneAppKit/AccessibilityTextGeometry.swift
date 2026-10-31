#if canImport(AppKit)
import AppKit

/// Conservative text geometry for AppKit accessibility. It never typesets or
/// scrolls to answer a query; stale, detached and off-viewport geometry is
/// unavailable. Ranges use UTF-16 offsets into the installed view snapshot.
enum AccessibilityTextGeometry {
    /// The first contiguous range of fully visible fragments in the current
    /// viewport. Partially clipped fragments are omitted rather than claiming
    /// that all their characters are visible. Empty lines and line delimiters
    /// count when their line is visible. Hidden wrap whitespace is included
    /// only between visible fragments, never as an unrendered trailing tail.
    static func visibleRange(in view: ReadOnlyDocumentView) -> NSRange? {
        let geometryRevision = view.inputGeometryRevision
        let contentRevision = view.contentRevision
        guard !view.isRetired, !view.isHiddenOrHasHiddenAncestor, !view.updatingViewport,
              let window = view.window, window.isVisible,
              let clip = view.enclosingScrollView?.contentView,
              let layout = view.visibleLayout, layout.isComplete,
              layout.viewport == clip.bounds, validViewport(layout.viewport) else { return nil }
        let visibleRect = view.visibleRect
        let effectiveViewport = layout.viewport.intersection(visibleRect)
        guard validViewport(visibleRect), validViewport(effectiveViewport) else { return nil }
        let text = view.manager.stringView.string
        var first: Int?
        var end = 0
        var continuationEnd = 0
        var stopped = false

        func include(start: Int, visibleEnd: Int, nextStartLimit: Int) {
            guard !stopped, start >= 0, start <= visibleEnd, visibleEnd <= nextStartLimit,
                  nextStartLimit <= text.length,
                  scalarBoundary(start, text: text), scalarBoundary(visibleEnd, text: text),
                  scalarBoundary(nextStartLimit, text: text) else { return }
            if first == nil {
                first = start
                end = visibleEnd
                continuationEnd = nextStartLimit
            } else if start <= continuationEnd && visibleEnd >= end {
                end = visibleEnd
                continuationEnd = max(continuationEnd, nextStartLimit)
            } else {
                // A clipped or folded portion cannot be represented as one
                // continuous visible range. Keep only the earlier portion.
                stopped = true
            }
        }

        for lineLayout in layout.lines where !stopped {
            let line = lineLayout.line
            guard line.location >= 0, line.data.length >= 0, line.data.totalLength >= line.data.length,
                  line.location <= text.length, line.data.totalLength <= text.length - line.location else { continue }
            let lineEnd = line.location + line.data.length
            let lineTotalEnd = line.location + line.data.totalLength
            if line.data.length == 0 {
                let lineRect = CGRect(x: 0, y: line.yPosition, width: 1, height: line.data.lineHeight)
                if fullyVisible(lineRect, in: effectiveViewport) {
                    include(start: line.location, visibleEnd: lineTotalEnd, nextStartLimit: lineTotalEnd)
                }
                continue
            }
            for placement in lineLayout.placements where !stopped {
                guard fullyVisible(placement.frame, in: effectiveViewport) else { continue }
                let visible = placement.fragment.visibleRange
                let fragment = placement.fragment.range
                // The typesetter receives the complete logical line, including
                // its delimiter. Its final fragment may therefore extend past
                // line.data.length while remaining inside totalLength.
                guard visible.location >= 0, visible.length >= 0, fragment.location == visible.location,
                      visible.location <= line.data.totalLength,
                      visible.length <= line.data.totalLength - visible.location,
                      fragment.length >= visible.length,
                      fragment.length <= line.data.totalLength - fragment.location else { continue }
                let start = line.location + visible.location
                var visibleEnd = start + visible.length
                let logicalEnd = line.location + fragment.upperBound
                let continuation = logicalEnd == lineEnd ? lineTotalEnd : logicalEnd
                if logicalEnd == lineEnd && visibleEnd == logicalEnd { visibleEnd = lineTotalEnd }
                // A hidden delimiter still represents the visible line break;
                // unlike hidden wrap whitespace, it may be exposed at the end.
                if logicalEnd == lineTotalEnd && visibleEnd == lineEnd { visibleEnd = lineTotalEnd }
                include(start: start, visibleEnd: visibleEnd, nextStartLimit: continuation)
            }
        }
        guard let start = first, !view.isRetired, !view.isHiddenOrHasHiddenAncestor, !view.updatingViewport,
              view.window === window, window.isVisible, view.enclosingScrollView?.contentView === clip,
              clip.bounds == layout.viewport, view.visibleRect == visibleRect,
              view.inputGeometryRevision == geometryRevision, view.contentRevision == contentRevision else { return nil }
        return NSRange(location: start, length: end - start)
    }

    /// Returns a screen rectangle only when the input geometry helper resolved
    /// the entire requested range; it otherwise describes just one visual run.
    static func frame(for range: NSRange, in view: ReadOnlyDocumentView) -> NSRect? {
        let geometryRevision = view.inputGeometryRevision
        let contentRevision = view.contentRevision
        guard !view.isRetired, !view.isHiddenOrHasHiddenAncestor, !view.updatingViewport,
              let window = view.window, window.isVisible, let clip = view.enclosingScrollView?.contentView,
              let layout = view.visibleLayout, layout.isComplete, layout.viewport == clip.bounds else { return nil }
        let visibleRect = view.visibleRect
        let effectiveViewport = layout.viewport.intersection(visibleRect)
        guard validViewport(visibleRect), validViewport(effectiveViewport),
              let result = InputScreenRangeGeometry.firstRect(for: range, in: view), result.actualRange == range else { return nil }
        let documentFrame = view.convert(window.convertFromScreen(result.rect), from: nil)
        guard fullyVisible(documentFrame, in: effectiveViewport), !view.isRetired, !view.isHiddenOrHasHiddenAncestor,
              !view.updatingViewport, view.window === window, window.isVisible,
              view.enclosingScrollView?.contentView === clip, clip.bounds == layout.viewport,
              view.visibleRect == visibleRect, view.inputGeometryRevision == geometryRevision,
              view.contentRevision == contentRevision else { return nil }
        return result.rect
    }

    /// Resolves the composed character actually under a screen point. The
    /// input hit test returns the nearest insertion boundary, so the character
    /// can lie on either side. Accept only one complete candidate whose real
    /// frame contains the point; ambiguous and partial-run hits are unavailable.
    static func range(at point: NSPoint, in view: ReadOnlyDocumentView) -> NSRange? {
        let geometryRevision = view.inputGeometryRevision
        let contentRevision = view.contentRevision
        guard point.x.isFinite, point.y.isFinite, !view.isRetired, !view.isHiddenOrHasHiddenAncestor,
              !view.updatingViewport, let window = view.window, window.isVisible,
              let clip = view.enclosingScrollView?.contentView,
              let layout = view.visibleLayout, layout.isComplete, layout.viewport == clip.bounds else { return nil }
        let visibleRect = view.visibleRect
        let effectiveViewport = layout.viewport.intersection(visibleRect)
        guard validViewport(visibleRect), validViewport(effectiveViewport) else { return nil }
        let documentPoint = view.convert(window.convertPoint(fromScreen: point), from: nil)
        guard effectiveViewport.contains(documentPoint),
              let insertion = InputScreenRangeGeometry.characterIndex(for: point, in: view) else { return nil }
        let text = view.manager.stringView.string
        guard insertion >= 0, insertion <= text.length else { return nil }
        var candidates: [NSRange] = []
        if insertion > 0 { candidates.append(text.rangeOfComposedCharacterSequence(at: insertion - 1)) }
        if insertion < text.length {
            let next = text.rangeOfComposedCharacterSequence(at: insertion)
            if !candidates.contains(next) { candidates.append(next) }
        }
        let matches = candidates.filter { candidate in
            guard candidate.location != NSNotFound, candidate.location >= 0, candidate.length > 0,
                  candidate.location <= text.length, candidate.length <= text.length - candidate.location,
                  let candidateFrame = frame(for: candidate, in: view) else { return false }
            return candidateFrame.contains(point)
        }
        guard matches.count == 1, !view.isRetired, !view.isHiddenOrHasHiddenAncestor, !view.updatingViewport,
              view.window === window, window.isVisible, view.enclosingScrollView?.contentView === clip,
              clip.bounds == layout.viewport, view.visibleRect == visibleRect,
              view.inputGeometryRevision == geometryRevision, view.contentRevision == contentRevision else { return nil }
        return matches[0]
    }

    private static func validViewport(_ rect: CGRect) -> Bool {
        rect.minX.isFinite && rect.minY.isFinite && rect.maxX.isFinite && rect.maxY.isFinite &&
            rect.width > 0 && rect.height > 0
    }

    private static func fullyVisible(_ rect: CGRect, in viewport: CGRect) -> Bool {
        rect.minX.isFinite && rect.minY.isFinite && rect.maxX.isFinite && rect.maxY.isFinite &&
            rect.width >= 0 && rect.height > 0 && rect.minX >= viewport.minX && rect.maxX <= viewport.maxX &&
            rect.minY >= viewport.minY && rect.maxY <= viewport.maxY
    }

    private static func scalarBoundary(_ offset: Int, text: NSString) -> Bool {
        offset == 0 || offset == text.length ||
            !(0xD800...0xDBFF).contains(text.character(at: offset - 1)) ||
            !(0xDC00...0xDFFF).contains(text.character(at: offset))
    }
}
#endif
