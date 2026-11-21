#if canImport(AppKit)
import AppKit

/// A search occurrence a host presents over the document, for example the
/// results of a search across files.
public struct RunestoneSearchOccurrence: Equatable {
    /// The occurrence, in UTF-16 units of the document.
    public var range: NSRange
    /// Non-nil previews replacing the occurrence with this literal text: the
    /// occurrence is struck through and the text is shown after it. An empty
    /// string previews a deletion.
    public var replacement: String?

    public init(range: NSRange, replacement: String? = nil) {
        self.range = range
        self.replacement = replacement
    }
}

/// Presents search occurrences without dimming the document, so they can stay
/// up while the user edits. An occurrence looks like the find bar's current
/// match. A replacement preview is a diff: the occurrence struck through on red,
/// followed by the replacement on green.
///
/// The document's layout does not contain the previewed text. The rest of the
/// visual line is drawn again, by the editor's own line renderer, moved right
/// to make room. The preview therefore does not rewrap: text pushed past the
/// right edge is clipped, and an occurrence that spans visual lines is only
/// struck through.
final class SearchOccurrencePresentationView: NSView {
    weak var editor: ReadOnlyDocumentView?
    var occurrences: [RunestoneSearchOccurrence] = []
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private static let plateRadius: CGFloat = 3
    private static let insertionSpacing: CGFloat = 2

    override func draw(_ dirtyRect: NSRect) {
        guard let editor, !occurrences.isEmpty, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let origin = convert(NSPoint.zero, from: editor)
        context.translateBy(x: origin.x, y: origin.y)
        let background = editor.enclosingScrollView?.backgroundColor ?? .textBackgroundColor
        let colors = TextFinderPresentationColors(editorBackground: background)
        let font = editor.displayConfiguration.textFont ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let visible = editor.textFinderVisibleCharacterRanges
        // Occurrences on one visual line are placed together, because an inserted
        // replacement moves everything after it on that line.
        var lines: [Int: [(occurrence: RunestoneSearchOccurrence, rect: NSRect)]] = [:]
        for occurrence in occurrences where visible.contains(where: { NSIntersectionRange($0, occurrence.range).length > 0 }) {
            let rects = editor.textFinderRects(for: occurrence.range)
            if rects.count == 1 {
                lines[Int(rects[0].midY.rounded()), default: []].append((occurrence, rects[0]))
            } else {
                for rect in rects { mark(occurrence, rect: rect, shift: 0, colors: colors, editor: editor, context: context) }
            }
        }
        for line in lines.values {
            let placed = line.sorted { $0.rect.minX < $1.rect.minX }
            guard placed.contains(where: { $0.occurrence.replacement?.isEmpty == false }), let first = placed.first else {
                for item in placed { mark(item.occurrence, rect: item.rect, shift: 0, colors: colors, editor: editor, context: context) }
                continue
            }
            let top = placed.map(\.rect.minY).min() ?? first.rect.minY
            let bottom = placed.map(\.rect.maxY).max() ?? first.rect.maxY
            let strip = NSRect(x: first.rect.minX, y: top, width: editor.bounds.maxX - first.rect.minX, height: bottom - top)
            guard strip.width > 0, strip.height > 0 else { continue }
            context.setFillColor(background.cgColor)
            context.fill(strip)
            var shift: CGFloat = 0
            var cursor = strip.minX
            for item in placed {
                editor.drawDocumentContent(in: NSRect(x: cursor, y: strip.minY, width: item.rect.maxX - cursor, height: strip.height),
                                           shiftedBy: shift, in: context)
                mark(item.occurrence, rect: item.rect, shift: shift, colors: colors, editor: editor, context: context)
                cursor = item.rect.maxX
                guard let replacement = item.occurrence.replacement, !replacement.isEmpty else { continue }
                let text = String(replacement.prefix(200)).components(separatedBy: .newlines).joined(separator: "↵")
                let inserted = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: colors.matchForeground])
                let size = inserted.size()
                let plate = NSRect(x: item.rect.maxX + shift + Self.insertionSpacing, y: item.rect.minY,
                                   width: ceil(size.width), height: item.rect.height)
                NSColor.systemGreen.withAlphaComponent(0.3).setFill()
                NSBezierPath(roundedRect: plate.insetBy(dx: -1, dy: 0), xRadius: Self.plateRadius, yRadius: Self.plateRadius).fill()
                inserted.draw(at: NSPoint(x: plate.minX, y: plate.midY - size.height / 2))
                shift += plate.width + Self.insertionSpacing * 2
            }
            editor.drawDocumentContent(in: NSRect(x: cursor, y: strip.minY, width: strip.maxX - cursor, height: strip.height),
                                       shiftedBy: shift, in: context)
        }
    }

    /// One occurrence's plate, moved right by the insertions before it on its line.
    private func mark(_ occurrence: RunestoneSearchOccurrence, rect: NSRect, shift: CGFloat, colors: TextFinderPresentationColors,
                      editor: ReadOnlyDocumentView, context: CGContext) {
        let rect = rect.offsetBy(dx: shift, dy: 0)
        // The find bar's plate: one point wider than the text, with a three-point radius.
        let plate = CGPath(roundedRect: rect.insetBy(dx: -1, dy: 0), cornerWidth: Self.plateRadius, cornerHeight: Self.plateRadius, transform: nil)
        context.addPath(plate)
        if occurrence.replacement != nil {
            context.setFillColor(NSColor.systemRed.withAlphaComponent(0.28).cgColor)
            context.fillPath()
            context.setFillColor(colors.matchForeground.withAlphaComponent(0.75).cgColor)
            context.fill(CGRect(x: rect.minX, y: rect.midY.rounded(), width: rect.width, height: 1))
        } else {
            context.setFillColor(colors.selectedBackground.cgColor)
            context.fillPath()
            context.saveGState()
            context.translateBy(x: shift, y: 0)
            editor.drawTextFinderCharacters(in: occurrence.range, foregroundColor: colors.selectedForeground)
            context.restoreGState()
        }
    }
}

extension ReadOnlyDocumentView {
    func setSearchOccurrences(_ occurrences: [RunestoneSearchOccurrence]) {
        if occurrences.isEmpty {
            searchOccurrencePresentationView?.removeFromSuperview()
            searchOccurrencePresentationView = nil
            return
        }
        let overlay: SearchOccurrencePresentationView
        if let existing = searchOccurrencePresentationView {
            overlay = existing
        } else {
            overlay = SearchOccurrencePresentationView()
            overlay.editor = self
            overlay.setAccessibilityElement(false)
            searchOccurrencePresentationView = overlay
        }
        guard overlay.occurrences != occurrences || overlay.superview == nil else { return }
        overlay.occurrences = occurrences
        updateSearchOccurrencePresentation()
    }

    /// Keeps the presentation over the visible document. The find bar's dimmed
    /// presentation, when shown, stays above it.
    func updateSearchOccurrencePresentation() {
        guard let overlay = searchOccurrencePresentationView else { return }
        guard let clip = enclosingScrollView?.contentView else {
            overlay.removeFromSuperview()
            return
        }
        if overlay.superview !== clip {
            if let finder = textFinderPresentationView, finder.superview === clip {
                clip.addSubview(overlay, positioned: .below, relativeTo: finder)
            } else {
                clip.addSubview(overlay, positioned: .above, relativeTo: nil)
            }
        }
        overlay.frame = clip.bounds
        overlay.needsDisplay = true
    }
}
#endif
