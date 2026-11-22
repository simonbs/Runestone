#if canImport(AppKit)
import AppKit
import CoreText

extension ReadOnlyDocumentView {
    /// Animation state only: canonical text, attributes, selection, and undo are untouched.
    public func setWritingToolsPresentation(hiddenRanges: [NSRange], dimmedRanges: [NSRange]) {
        writingToolsHiddenRanges = hiddenRanges
        writingToolsDimmedRanges = dimmedRanges
        needsDisplay = true
    }

    public func writingToolsTextRects(for range: NSRange) -> [NSRect] {
        textFinderRects(for: range)
    }

    /// Uses the very same Core Text fragments as the editor, without its background,
    /// selection, caret, invisibles, or temporary animation hiding. Work and bitmap
    /// size are bounded by the visible viewport even for whole-document requests.
    public func writingToolsPreview(for range: NSRange) -> NSTextPreview? {
        makeWritingToolsPreview(rects: writingToolsTextRects(for: range), grammarUnderline: false)
    }

    public func writingToolsPreview(for rect: NSRect) -> NSTextPreview? {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite else { return nil }
        let clipped = rect.intersection(visibleRect)
        guard !clipped.isNull, !clipped.isEmpty else { return nil }
        return makeWritingToolsPreview(rects: [clipped], grammarUnderline: false)
    }

    public func writingToolsGrammarPreview(for range: NSRange) -> NSTextPreview? {
        makeWritingToolsPreview(rects: writingToolsTextRects(for: range), grammarUnderline: true)
    }

    private func makeWritingToolsPreview(rects: [CGRect], grammarUnderline: Bool, gray: Bool = false) -> NSTextPreview? {
        guard !isRetired, let layout = visibleLayout, layout.isComplete, !updatingViewport else { return nil }
        let rects = rects.map { $0.intersection(visibleRect) }.filter { !$0.isEmpty && !$0.isNull }
        guard !rects.isEmpty else { return nil }
        let frame = rects.reduce(CGRect.null) { $0.union($1) }.integral
        let scale = window?.backingScaleFactor ?? 2
        guard frame.width > 0, frame.height > 0,
              let context = CGContext(data: nil, width: Int(ceil(frame.width * scale)),
                                      height: Int(ceil(frame.height * scale)), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -frame.minX, y: -frame.maxY)
        context.clip(to: rects)
        for line in layout.lines {
            for placement in line.placements where placement.frame.intersects(frame) {
                context.saveGState()
                context.translateBy(x: placement.frame.minX, y: placement.frame.minY)
                LineFragmentRenderer.drawGlyphs(placement.fragment, in: context)
                context.restoreGState()
            }
        }
        if gray {
            context.setBlendMode(.sourceIn)
            context.setFillColor(NSColor(calibratedWhite: 0.5, alpha: 1).cgColor)
            context.fill(frame)
        }
        if grammarUnderline { drawWritingToolsUnderlines(rects, in: context) }
        guard let image = context.makeImage() else { return nil }
        return NSTextPreview(snapshotImage: image, presentationFrame: frame,
                             candidateRects: rects.map { NSValue(rect: $0) })
    }

    func clipWritingToolsHiddenText(in context: CGContext) {
        // Union overlaps before using an even-odd clip; overlapping animation
        // ranges must never accidentally reveal the text underneath.
        let ranges = (writingToolsHiddenRanges + writingToolsDimmedRanges)
            .filter { $0.location != NSNotFound && $0.length > 0 }
            .sorted { $0.location < $1.location }
            .reduce(into: [NSRange]()) { result, range in
                if let last = result.last, NSMaxRange(last) >= range.location {
                    result[result.count - 1] = NSUnionRange(last, range)
                } else { result.append(range) }
            }
        // Geometry may itself overlap at bidi boundaries; clip each hole separately.
        for range in ranges {
            for rect in writingToolsTextRects(for: range) {
                let hole = CGMutablePath()
                hole.addRect(bounds)
                hole.addRect(rect)
                context.addPath(hole)
                context.clip(using: .evenOdd)
            }
        }
    }

    func drawWritingToolsDimmedText(in context: CGContext) {
        let ranges = writingToolsDimmedRanges.sorted { $0.location < $1.location }.reduce(into: [NSRange]()) { result, range in
            if let last = result.last, NSMaxRange(last) >= range.location { result[result.count - 1] = NSUnionRange(last, range) }
            else { result.append(range) }
        }
        let visibleRanges = writingToolsHiddenRanges.reduce(ranges) { remaining, hidden in
            remaining.flatMap { range -> [NSRange] in
                let overlap = NSIntersectionRange(range, hidden)
                guard overlap.length > 0 else { return [range] }
                var fragments: [NSRange] = []
                if range.location < overlap.location {
                    fragments.append(NSRange(location: range.location, length: overlap.location - range.location))
                }
                if NSMaxRange(overlap) < NSMaxRange(range) {
                    fragments.append(NSRange(location: NSMaxRange(overlap), length: NSMaxRange(range) - NSMaxRange(overlap)))
                }
                return fragments
            }
        }
        for range in visibleRanges {
            guard let preview = makeWritingToolsPreview(rects: writingToolsTextRects(for: range), grammarUnderline: false, gray: true) else { continue }
            context.saveGState()
            for hidden in writingToolsHiddenRanges.flatMap({ writingToolsTextRects(for: $0) }) {
                let hole = CGMutablePath()
                hole.addRect(bounds)
                hole.addRect(hidden)
                context.addPath(hole)
                context.clip(using: .evenOdd)
            }
            let frame = preview.presentationFrame
            context.translateBy(x: frame.minX, y: frame.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(preview.previewImage, in: CGRect(origin: .zero, size: frame.size))
            context.restoreGState()
        }
    }

    func handleWritingToolsGrammarClick(_ event: NSEvent) -> Bool {
        guard event.clickCount == 1, event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty else { return false }
        let point = convert(event.locationInWindow, from: nil)
        guard let range = writingToolsGrammarRanges.first(where: { range in
            writingToolsTextRects(for: range).contains { $0.contains(point) }
        }) else { return false }
        return writingToolsGrammarClick?(range) == true
    }

    func drawWritingToolsGrammar(in context: CGContext) {
        guard !isWritingToolsActive else { return }
        drawWritingToolsUnderlines(writingToolsGrammarRanges.flatMap { writingToolsTextRects(for: $0) }, in: context)
    }

    private func drawWritingToolsUnderlines(_ rects: [CGRect], in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [1, 2])
        for rect in rects {
            context.move(to: CGPoint(x: rect.minX, y: rect.maxY - 1))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 1))
        }
        context.strokePath()
        context.restoreGState()
    }
}

/// A noninteractive copy of the renderer used only for system grammar previews.
/// The document input surface remains canonical, including its accessibility value.
final class WritingToolsTemporaryPresentation: NSScrollView {
    let textView: ReadOnlyDocumentView
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    init(editor: ReadOnlyDocumentView, content: NSAttributedString) {
        textView = ReadOnlyDocumentView(content: content)
        super.init(frame: editor.visibleRect)
        drawsBackground = true
        backgroundColor = editor.enclosingScrollView?.backgroundColor ?? .textBackgroundColor
        textView.displayConfiguration = editor.displayConfiguration
        documentView = textView
        setAccessibilityElement(false)
        setAccessibilityHidden(true)
        textView.setAccessibilityHidden(true)
    }

    required init?(coder: NSCoder) { nil }

    func synchronize(with editor: ReadOnlyDocumentView) {
        frame = editor.visibleRect
        tile()
        textView.updateViewport()
        contentView.scroll(to: editor.enclosingScrollView?.contentView.bounds.origin ?? .zero)
        reflectScrolledClipView(contentView)
        textView.updateViewport()
    }
}

extension ReadOnlyDocumentView {
    /// Shows a transient system grammar revision without an edit, autosave,
    /// undo registration, accessibility value change, or document publication.
    public func showWritingToolsTemporaryText(_ text: String?) {
        writingToolsTemporaryPresentation?.removeFromSuperview()
        writingToolsTemporaryPresentation = nil
        guard let text else { return }
        let attributes = content.length > 0 ? content.attributes(at: 0, effectiveRange: nil) : [
            .font: displayConfiguration.textFont ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        let overlay = WritingToolsTemporaryPresentation(editor: self, content: NSAttributedString(string: text, attributes: attributes))
        addSubview(overlay, positioned: .above, relativeTo: nil)
        writingToolsTemporaryPresentation = overlay
        overlay.synchronize(with: self)
    }

    public var writingToolsPreviewView: ReadOnlyDocumentView {
        if let overlay = writingToolsTemporaryPresentation {
            overlay.synchronize(with: self)
            return overlay.textView
        }
        return self
    }
}
#endif
