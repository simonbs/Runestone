#if canImport(AppKit)
import AppKit

extension ReadOnlyDocumentView {
    /// Search geometry is presentation state, not an accessibility or IME query.
    /// Never lay out offscreen text to answer AppKit's incremental-search calls.
    var textFinderVisibleCharacterRanges: [NSRange] {
        guard let viewport = textFinderViewport, let layout = visibleLayout else { return [] }
        let length = content.length
        var ranges: [NSRange] = []
        for line in layout.lines {
            for placement in line.placements where placement.frame.intersects(viewport) {
                let start = line.line.location + placement.fragment.range.location
                guard start >= 0, start < length else { continue }
                let range = NSRange(location: start, length: min(placement.fragment.range.length, length - start))
                guard range.length > 0 else { continue }
                if let previous = ranges.last, NSMaxRange(previous) >= start {
                    ranges[ranges.count - 1] = NSUnionRange(previous, range)
                } else {
                    ranges.append(range)
                }
            }
        }
        return ranges
    }

    func textFinderRects(for range: NSRange) -> [NSRect] {
        guard range.length > 0, let viewport = textFinderViewport,
              let geometry = InputSelectionGeometry.geometry(selection: range, marked: nil, in: self) else { return [] }
        return geometry.selectionRects.compactMap { rect in
            let clipped = rect.intersection(viewport)
            return clipped.isNull || clipped.isEmpty ? nil : clipped
        }
    }

    private var textFinderViewport: NSRect? {
        guard !isRetired, !isHiddenOrHasHiddenAncestor, !updatingViewport,
              window?.isVisible == true, let clip = enclosingScrollView?.contentView,
              let layout = visibleLayout, layout.isComplete, layout.viewport == clip.bounds else { return nil }
        let textViewport = NSRect(x: layout.viewport.minX + gutterWidth, y: layout.viewport.minY,
                                  width: max(0, layout.viewport.width - gutterWidth), height: layout.viewport.height)
        let viewport = textViewport.intersection(visibleRect)
        guard !viewport.isNull, !viewport.isEmpty else { return nil }
        return viewport
    }
}
#endif
