#if canImport(AppKit)
import AppKit

/// Find is a presentation overlay: canonical text, syntax, and selection colors
/// remain untouched. The overlay includes the pinned gutter and ignores input.
final class TextFinderPresentationView: NSView {
    weak var editor: ReadOnlyDocumentView?
    var ranges: [NSRange] = []
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let editor, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)
        let origin = convert(NSPoint.zero, from: editor)
        context.translateBy(x: origin.x, y: origin.y)
        let visibleRanges = editor.textFinderVisibleCharacterRanges
        let visibleMatches = ranges.filter { range in
            visibleRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }
        for range in visibleMatches {
            let rects = editor.textFinderRects(for: range)
            guard !rects.isEmpty else { continue }
            let selected = editor.presentedSelectionRange == range
            context.setFillColor((selected ? NSColor.findHighlightColor : .white).cgColor)
            for rect in rects {
                context.addPath(CGPath(roundedRect: rect.insetBy(dx: -1, dy: 0), cornerWidth: 3, cornerHeight: 3, transform: nil))
                context.fillPath()
            }
        }
        editor.drawTextFinderCharacters(in: visibleMatches, foregroundColor: .black)
    }
}

extension ReadOnlyDocumentView {
    func setTextFinderMatches(_ ranges: [NSRange]) {
        if ranges.isEmpty {
            textFinderPresentationView?.removeFromSuperview()
            textFinderPresentationView = nil
            return
        }
        let overlay: TextFinderPresentationView
        if let existing = textFinderPresentationView {
            overlay = existing
        } else {
            overlay = TextFinderPresentationView()
            overlay.editor = self
            overlay.setAccessibilityElement(false)
            textFinderPresentationView = overlay
            enclosingScrollView?.contentView.addSubview(overlay, positioned: .above, relativeTo: nil)
        }
        overlay.ranges = ranges
        updateTextFinderPresentation()
    }

    func updateTextFinderPresentation() {
        guard let overlay = textFinderPresentationView else { return }
        guard let clip = enclosingScrollView?.contentView else {
            overlay.removeFromSuperview()
            return
        }
        if overlay.superview !== clip { clip.addSubview(overlay, positioned: .above, relativeTo: nil) }
        overlay.frame = clip.bounds
        overlay.needsDisplay = true
    }

    /// Draw the existing shaped glyphs through a color mask. This preserves
    /// ligatures, bidi placement and fonts without repainting token backgrounds
    /// over the result plate or reshaping text with different attributes.
    func drawTextFinderCharacters(in range: NSRange, foregroundColor: NSColor) {
        drawTextFinderCharacters(in: [range], foregroundColor: foregroundColor)
    }

    func drawTextFinderCharacters(in ranges: [NSRange], foregroundColor: NSColor) {
        let rects = ranges.flatMap { textFinderRects(for: $0) }
        guard !rects.isEmpty, let layout = visibleLayout, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rects)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        for line in layout.lines {
            for placement in line.placements where rects.contains(where: { $0.intersects(placement.frame) }) {
                context.saveGState()
                context.translateBy(x: placement.frame.minX, y: placement.frame.minY)
                LineFragmentRenderer.drawGlyphs(placement.fragment, in: context)
                context.restoreGState()
            }
        }
        context.setBlendMode(.sourceIn)
        context.setFillColor(foregroundColor.cgColor)
        for rect in rects { context.fill(rect) }
        context.endTransparencyLayer()
    }
}
#endif
