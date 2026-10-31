#if canImport(AppKit)
import AppKit

/// Resolves caret positions from the current viewport without changing layout.
/// A detached view, an offscreen position, or a stale viewport has no result.
/// This is an internal building block, not an interactive input host.
enum InputScreenCaretGeometry {
    static func rect(at location: Int, in view: ReadOnlyDocumentView, caretWidth: CGFloat = 1) -> NSRect? {
        let geometryRevision = view.inputGeometryRevision
        guard !view.updatingViewport, caretWidth.isFinite, caretWidth > 0, let window = view.window,
              let clip = view.enclosingScrollView?.contentView,
              let layout = view.visibleLayout, layout.isComplete,
              layout.viewport == clip.bounds,
              location >= 0, location <= view.manager.stringView.string.length,
              let line = view.manager.line(containingCharacterAt: location),
              let lineLayout = layout.lines.first(where: { $0.line === line }) else { return nil }

        let text = view.manager.stringView.string
        if location > 0 && location < text.length &&
            (0xD800...0xDBFF).contains(text.character(at: location - 1)) &&
            (0xDC00...0xDFFF).contains(text.character(at: location)) { return nil }
        let lineEnd = line.location + line.data.length
        let offset = min(location, lineEnd)
        let placement = lineLayout.placements.first {
            let range = $0.fragment.range
            return line.location + range.location <= offset && offset < line.location + range.upperBound
        } ?? (offset == lineEnd ? lineLayout.placements.last {
            line.location + $0.fragment.range.upperBound == offset
        } : nil)
        let documentRect: NSRect
        if let placement = placement {
            guard let rect = InputCaretGeometry.rect(for: placement, lineStart: line.location,
                                                     documentOffset: offset, caretWidth: caretWidth) else { return nil }
            documentRect = rect
        } else {
            guard line.data.length == 0, offset == line.location,
                  line.data.lineHeight.isFinite, line.data.lineHeight > 0 else { return nil }
            documentRect = NSRect(x: 0, y: line.yPosition, width: caretWidth, height: line.data.lineHeight)
        }
        guard documentRect.intersects(layout.viewport) else { return nil }
        let result = window.convertToScreen(view.convert(documentRect, to: nil))
        guard !view.updatingViewport, geometryRevision == view.inputGeometryRevision, view.window === window,
              view.enclosingScrollView?.contentView === clip, layout.viewport == clip.bounds else { return nil }
        return result
    }
}
#endif
