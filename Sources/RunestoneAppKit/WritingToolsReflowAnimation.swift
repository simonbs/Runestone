#if canImport(AppKit)
import AppKit

/// Pure geometry for native animation progress. Kept separate from rendering so
/// it can be checked without a window, application launch, or system animation.
struct WritingToolsReflowFrame {
    let old: CGRect
    let new: CGRect

    func presentation(at progress: Float) -> (old: CGRect, new: CGRect, progress: CGFloat) {
        let progress = progress.isFinite ? CGFloat(min(1, max(0, progress))) : 1
        let dx = new.minX - old.minX
        let dy = new.minY - old.minY
        return (old.offsetBy(dx: dx * progress, dy: dy * progress),
                new.offsetBy(dx: -dx * (1 - progress), dy: -dy * (1 - progress)), progress)
    }
}

/// Viewport-bounded snapshots of trailing glyphs, driven by the system's own
/// animation clock. No text, selection, accessibility, or document state changes.
public final class RunestoneWritingToolsReflowAnimation {
    private weak var editor: ReadOnlyDocumentView?
    private let before: NSTextPreview
    private var overlay: WritingToolsReflowOverlay?
    private var finished = false

    init(editor: ReadOnlyDocumentView, before: NSTextPreview) {
        self.editor = editor
        self.before = before
    }

    public func start(after range: NSRange) {
        guard !finished, overlay == nil, let editor, let after = editor.writingToolsPreview(for: range) else { finish(); return }
        editor.cancelWritingToolsReflowAnimation()
        let overlay = WritingToolsReflowOverlay(before: before, after: after)
        overlay.frame = editor.bounds
        overlay.autoresizingMask = [.width, .height]
        editor.addSubview(overlay, positioned: .above, relativeTo: nil)
        self.overlay = overlay
        editor.writingToolsReflowAnimation = self
        editor.writingToolsReflowHiddenRange = range
        editor.needsDisplay = true
    }

    public func updateProgress(_ progress: Float) {
        guard !finished, let editor, editor.writingToolsReflowAnimation === self else { return }
        overlay?.progress = progress
    }

    public func finish() {
        guard !finished else { return }
        finished = true
        overlay?.removeFromSuperview()
        overlay = nil
        if let editor, editor.writingToolsReflowAnimation === self {
            editor.writingToolsReflowAnimation = nil
            editor.writingToolsReflowHiddenRange = nil
            editor.needsDisplay = true
        }
    }
}

private final class WritingToolsReflowOverlay: NSView {
    let before: NSTextPreview
    let after: NSTextPreview
    var progress: Float = 0 { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    init(before: NSTextPreview, after: NSTextPreview) {
        self.before = before
        self.after = after
        super.init(frame: .zero)
        setAccessibilityElement(false)
        setAccessibilityHidden(true)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let frames = WritingToolsReflowFrame(old: before.presentationFrame, new: after.presentationFrame).presentation(at: progress)
        draw(before.previewImage, in: frames.old, alpha: 1 - frames.progress, context: context)
        draw(after.previewImage, in: frames.new, alpha: frames.progress, context: context)
    }

    private func draw(_ image: CGImage, in frame: CGRect, alpha: CGFloat, context: CGContext) {
        guard alpha > 0 else { return }
        context.saveGState()
        context.setAlpha(alpha)
        context.translateBy(x: frame.minX, y: frame.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: frame.size))
        context.restoreGState()
    }
}

extension ReadOnlyDocumentView {
    public func prepareWritingToolsReflow(replacing range: NSRange) -> RunestoneWritingToolsReflowAnimation? {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              range.location >= 0, range.length >= 0, range.location <= content.length,
              range.length <= content.length - range.location else { return nil }
        let end = NSMaxRange(range)
        guard end < content.length,
              let preview = writingToolsPreview(for: NSRange(location: end, length: content.length - end)) else { return nil }
        return RunestoneWritingToolsReflowAnimation(editor: self, before: preview)
    }

    public func cancelWritingToolsReflowAnimation() {
        writingToolsReflowAnimation?.finish()
    }
}
#endif
