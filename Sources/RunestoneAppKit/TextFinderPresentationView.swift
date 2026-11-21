#if canImport(AppKit)
import AppKit

/// Derive borderless result fills from the actual editor theme, including when
/// its brightness differs from the system appearance. Syntax colors cannot
/// guarantee contrast on a result plate, so choose black or white per fill.
struct TextFinderPresentationColors {
    let matchBackground: NSColor
    let matchForeground: NSColor
    let selectedBackground: NSColor
    let selectedForeground: NSColor

    init(editorBackground: NSColor) {
        let base = Self.opaqueRGB(editorBackground)
        let ink = Self.foreground(against: base)
        matchBackground = base.blended(withFraction: 0.2, of: ink) ?? base
        matchForeground = Self.foreground(against: matchBackground)
        selectedBackground = Self.opaqueRGB(.findHighlightColor)
        selectedForeground = Self.foreground(against: selectedBackground)
    }

    private static func opaqueRGB(_ color: NSColor) -> NSColor {
        let fallback = NSColor.textBackgroundColor.usingColorSpace(.sRGB) ?? .white
        let rgb = color.usingColorSpace(.sRGB) ?? fallback
        let alpha = min(1, max(0, rgb.alphaComponent))
        return NSColor(srgbRed: min(1, max(0, rgb.redComponent * alpha + fallback.redComponent * (1 - alpha))),
                       green: min(1, max(0, rgb.greenComponent * alpha + fallback.greenComponent * (1 - alpha))),
                       blue: min(1, max(0, rgb.blueComponent * alpha + fallback.blueComponent * (1 - alpha))), alpha: 1)
    }

    private static func foreground(against color: NSColor) -> NSColor {
        let rgb = color.usingColorSpace(.sRGB) ?? .white
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? .black : .white
    }
}

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
        let colors = TextFinderPresentationColors(editorBackground: editor.enclosingScrollView?.backgroundColor ?? .textBackgroundColor)
        let visibleRanges = editor.textFinderVisibleCharacterRanges
        let visibleMatches = ranges.filter { range in
            visibleRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }
        var selectedMatches: [NSRange] = []
        var otherMatches: [NSRange] = []
        for range in visibleMatches {
            let rects = editor.textFinderRects(for: range)
            guard !rects.isEmpty else { continue }
            let selected = editor.presentedSelectionRange == range
            if selected { selectedMatches.append(range) } else { otherMatches.append(range) }
            context.setFillColor((selected ? colors.selectedBackground : colors.matchBackground).cgColor)
            for rect in rects {
                context.addPath(CGPath(roundedRect: rect.insetBy(dx: -1, dy: 0), cornerWidth: 3, cornerHeight: 3, transform: nil))
                context.fillPath()
            }
        }
        editor.drawTextFinderCharacters(in: otherMatches, foregroundColor: colors.matchForeground)
        editor.drawTextFinderCharacters(in: selectedMatches, foregroundColor: colors.selectedForeground)
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
        updateSearchOccurrencePresentation()
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
