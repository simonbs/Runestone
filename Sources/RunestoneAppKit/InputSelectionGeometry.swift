#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneEngine

/// Viewport-limited presentation geometry in flipped document coordinates.
/// Directional runs remain separate so mixed-direction selections do not fill
/// unrelated text. This computes only from an already resolved viewport and
/// never triggers layout, scrolling, or input callbacks.
enum InputSelectionGeometry {
    struct Result {
        let selectionRects: [CGRect]
        let markedRects: [CGRect]
        let caretRect: CGRect?
    }

    static func geometry(selection: NSRange, marked: NSRange?, in view: ReadOnlyDocumentView,
                         caretWidth: CGFloat = 1, newlineWidth: CGFloat = 4) -> Result? {
        let revision = view.inputGeometryRevision
        let contentRevision = view.contentRevision
        let text = view.manager.stringView.string
        guard !view.isRetired, !view.updatingViewport, valid(selection, in: text),
              marked.map({ valid($0, in: text) }) ?? true,
              caretWidth.isFinite, caretWidth > 0, newlineWidth.isFinite, newlineWidth > 0,
              let clip = view.enclosingScrollView?.contentView,
              let layout = view.visibleLayout, layout.isComplete, layout.viewport == clip.bounds,
              finitePositive(layout.viewport) else { return nil }

        let selectionRects = selection.length == 0 ? [] : rects(for: selection, layout: layout, newlineWidth: newlineWidth)
        let markedRects = marked.map { rects(for: $0, layout: layout, newlineWidth: newlineWidth) } ?? []
        let caret = selection.length == 0
            ? caretRect(at: selection.location, view: view, layout: layout, width: caretWidth) : nil
        guard !view.isRetired, !view.updatingViewport, view.inputGeometryRevision == revision,
              view.contentRevision == contentRevision, view.enclosingScrollView?.contentView === clip,
              clip.bounds == layout.viewport else { return nil }
        return Result(selectionRects: selectionRects, markedRects: markedRects, caretRect: caret)
    }

    private static func rects(for range: NSRange, layout: ViewportLayoutCoordinator.Result,
                              newlineWidth: CGFloat) -> [CGRect] {
        guard range.length > 0 else { return [] }
        var result: [CGRect] = []
        for lineLayout in layout.lines {
            let line = lineLayout.line
            guard line.location >= 0, line.data.length >= 0, line.data.totalLength >= line.data.length,
                  line.location <= Int.max - line.data.totalLength else { continue }
            let lineEnd = line.location + line.data.length
            for placement in lineLayout.placements {
                let visible = placement.fragment.visibleRange
                guard visible.location >= 0, visible.length >= 0,
                      visible.location <= Int.max - visible.length,
                      line.location <= Int.max - visible.upperBound else { continue }
                let start = max(range.location, line.location + visible.location)
                let end = min(range.upperBound, line.location + visible.upperBound)
                if start < end {
                    let local = NSRange(location: start - line.location, length: end - start)
                    let geometry = CoreTextLineGeometry(line: placement.fragment.line, visibleRange: visible)
                    for segment in geometry.horizontalSegments(for: local) {
                        let rect = CGRect(x: placement.frame.minX + segment.lowerBound,
                                          y: placement.frame.minY + placement.fragment.verticalGeometry.textTop,
                                          width: segment.upperBound - segment.lowerBound,
                                          height: placement.fragment.baseSize.height)
                        if let clipped = clipped(rect, to: layout.viewport) { result.append(clipped) }
                    }
                }
                // Wrapped whitespace has no glyph. Show a small edge marker
                // only when the logical selection intersects that hidden tail.
                let hidden = placement.fragment.hiddenLength
                guard hidden > 0, visible.upperBound <= Int.max - hidden,
                      line.location <= Int.max - visible.upperBound - hidden else { continue }
                let hiddenStart = line.location + visible.upperBound
                let hiddenEnd = hiddenStart + hidden
                if range.location < hiddenEnd && range.upperBound > hiddenStart,
                   let marker = hiddenTailRect(placement, lineStart: line.location, width: newlineWidth),
                   let clipped = clipped(marker, to: layout.viewport) { result.append(clipped) }
            }
            // Delimiters have no glyph but still need a visible selection cell.
            if line.data.totalLength > line.data.length, range.location < line.location + line.data.totalLength,
               range.upperBound > lineEnd,
               let rect = lineEndRect(lineLayout, width: newlineWidth), let clipped = clipped(rect, to: layout.viewport) {
                result.append(clipped)
            }
        }
        return result
    }

    private static func caretRect(at offset: Int, view: ReadOnlyDocumentView,
                                  layout: ViewportLayoutCoordinator.Result, width: CGFloat) -> CGRect? {
        guard let line = view.manager.line(containingCharacterAt: offset),
              let lineLayout = layout.lines.first(where: { $0.line === line }) else { return nil }
        let local = min(offset, line.location + line.data.length)
        let placement = lineLayout.placements.first {
            line.location + $0.fragment.range.location <= local && local < line.location + $0.fragment.range.upperBound
        } ?? (local == line.location + line.data.length ? lineLayout.placements.last {
            line.location + $0.fragment.range.upperBound == local
        } : nil)
        let rect: CGRect?
        if let placement = placement {
            rect = InputCaretGeometry.rect(for: placement, lineStart: line.location, documentOffset: local, caretWidth: width)
        } else if line.data.length == 0 {
            rect = CGRect(x: 0, y: line.yPosition, width: width, height: line.data.lineHeight)
        } else { rect = nil }
        guard let rect = rect else { return nil }
        return clipped(rect, to: layout.viewport)
    }

    /// Hidden whitespace is collapsed at the logical trailing edge of the
    /// fragment. Resolve that edge from the terminal directional run, not the
    /// primary bidi caret, which may refer to an adjacent run.
    private static func hiddenTailRect(_ placement: LogicalLineLayoutController.Placement,
                                       lineStart: Int, width: CGFloat) -> CGRect? {
        let fragment = placement.fragment
        let end = fragment.visibleRange.upperBound
        guard fragment.visibleRange.length > 0,
              let runs = CTLineGetGlyphRuns(fragment.line) as? [CTRun],
              let run = runs.first(where: {
                  let range = CTRunGetStringRange($0)
                  return range.location >= 0 && range.length > 0 && range.location <= Int.max - range.length &&
                      range.location < end && end <= range.location + range.length
              }), let bounds = CoreTextRunGeometry.horizontalBounds(of: run),
              lineStart <= Int.max - end,
              let caret = InputCaretGeometry.rect(for: placement, lineStart: lineStart,
                                                   documentOffset: lineStart + end, caretWidth: width) else { return nil }
        let rtl = CTRunGetStatus(run).contains(.rightToLeft)
        let edge = placement.frame.minX + (rtl ? bounds.lowerBound : bounds.upperBound)
        guard edge.isFinite else { return nil }
        return CGRect(x: rtl ? edge - width : edge, y: caret.minY, width: width, height: caret.height)
    }

    private static func lineEndRect(_ lineLayout: ViewportLayoutCoordinator.LineLayout, width: CGFloat) -> CGRect? {
        let line = lineLayout.line
        if line.data.length == 0 { return CGRect(x: 0, y: line.yPosition, width: width, height: line.data.lineHeight) }
        guard let placement = lineLayout.placements.last(where: {
            $0.fragment.range.upperBound == line.data.length
        }) else { return nil }
        return InputCaretGeometry.rect(for: placement, lineStart: line.location,
                                       documentOffset: line.location + line.data.length, caretWidth: width)
    }

    private static func clipped(_ rect: CGRect, to viewport: CGRect) -> CGRect? {
        guard finitePositive(rect) else { return nil }
        let intersection = rect.intersection(viewport)
        return finitePositive(intersection) ? intersection : nil
    }

    private static func finitePositive(_ rect: CGRect) -> Bool {
        rect.minX.isFinite && rect.minY.isFinite && rect.maxX.isFinite && rect.maxY.isFinite &&
            rect.width.isFinite && rect.height.isFinite && rect.width > 0 && rect.height > 0
    }

    private static func valid(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return false }
        func boundary(_ index: Int) -> Bool {
            index == 0 || index == text.length ||
                !(0xD800...0xDBFF).contains(text.character(at: index - 1)) ||
                !(0xDC00...0xDFFF).contains(text.character(at: index))
        }
        return boundary(range.location) && boundary(range.upperBound)
    }
}
#endif
