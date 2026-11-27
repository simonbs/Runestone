#if canImport(AppKit)
import AppKit

/// The same SF Symbol and rotation convention as the UIKit gutter.
enum SyntaxFoldIndicator {
    private static let symbol = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
    private static let configuration = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .bold)

    static func image(color: NSColor) -> NSImage? {
        // Applying a color-only configuration to an already sized NSImage
        // replaces its size and weight. Combine the attributes first so the
        // rendered glyph keeps native source-list disclosure proportions.
        symbol?.withSymbolConfiguration(configuration.applying(.init(paletteColors: [color.withAlphaComponent(1)])))
    }

    static func draw(at center: CGPoint, collapsed: Bool, color: NSColor, in context: CGContext,
                     rotation: CGFloat? = nil) {
        guard let image = image(color: color) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation ?? (collapsed ? 0 : .pi / 2))
        image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                              width: image.size.width, height: image.size.height),
                   from: .zero, operation: .sourceOver, fraction: color.alphaComponent, respectFlipped: true, hints: nil)
    }
}

/// Animate two viewport-sized snapshots while the actual document geometry is
/// committed once. This keeps large folds bounded and input coordinates current.
final class SyntaxFoldingTransitionView: NSView, NSAnimationDelegate {
    let layoutRevision: UUID
    private let before: NSImage
    private let after: NSImage
    private let bodyTop: CGFloat
    private let oldTailTop: CGFloat
    private let newTailTop: CGFloat
    private let collapsing: Bool
    private let chevronCenter: CGPoint
    private let chevronColor: NSColor
    private let gutterColor: NSColor
    private let backgroundColor: NSColor
    private var animation: ProgressAnimation?
    private var completion: (() -> Void)?
    var progress: CGFloat = 0
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    init(viewport: CGRect, before: NSImage, after: NSImage, bodyTop: CGFloat,
         oldTailTop: CGFloat, newTailTop: CGFloat, collapsing: Bool,
         chevronCenter: CGPoint, chevronColor: NSColor, gutterColor: NSColor,
         backgroundColor: NSColor, layoutRevision: UUID) {
        self.before = before
        self.after = after
        self.bodyTop = bodyTop - viewport.minY
        self.oldTailTop = oldTailTop - viewport.minY
        self.newTailTop = newTailTop - viewport.minY
        self.collapsing = collapsing
        self.chevronCenter = CGPoint(x: chevronCenter.x, y: chevronCenter.y - viewport.minY)
        self.chevronColor = chevronColor
        self.gutterColor = gutterColor
        self.backgroundColor = backgroundColor
        self.layoutRevision = layoutRevision
        super.init(frame: viewport)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func start(completion: @escaping () -> Void) {
        self.completion = completion
        let animation = ProgressAnimation(duration: 0.324, animationCurve: .linear)
        animation.owner = self
        animation.animationBlockingMode = .nonblocking
        animation.frameRate = 60
        animation.delegate = self
        self.animation = animation
        animation.start()
    }

    func cancel() {
        animation?.stop()
        animation = nil
        completion = nil
        removeFromSuperview()
    }

    func animationDidEnd(_ animation: NSAnimation) {
        let completed = completion
        completion = nil
        self.animation = nil
        removeFromSuperview()
        completed?()
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        bounds.fill()
        let elapsed = progress * 0.324
        let fade = eased((elapsed - (collapsing ? 0 : 0.084)) / 0.24)
        let slide = eased((elapsed - (collapsing ? 0.048 : 0)) / (collapsing ? 0.192 : 0.24))
        let tailTop = oldTailTop + (newTailTop - oldTailTop) * slide
        draw(after, fromTop: 0, to: bodyTop)
        // The body fades separately while the following text slides into place.
        draw(collapsing ? before : after, fromTop: bodyTop,
             to: collapsing ? oldTailTop : newTailTop, opacity: collapsing ? 1 - fade : fade)
        let sourceTop = collapsing ? newTailTop : oldTailTop
        draw(collapsing ? after : before, fromTop: sourceTop, to: bounds.height,
             offset: tailTop - sourceTop)
        // Replace the captured glyph with a continuously rotating SF Symbol.
        gutterColor.setFill()
        CGRect(x: chevronCenter.x - 10, y: chevronCenter.y - 10, width: 20, height: 20).fill()
        if let context = NSGraphicsContext.current?.cgContext {
            let rotation = (collapsing ? 1 - eased(elapsed / 0.24) : eased(elapsed / 0.24)) * .pi / 2
            SyntaxFoldIndicator.draw(at: chevronCenter, collapsed: collapsing, color: chevronColor,
                                     in: context, rotation: rotation)
        }
    }

    private func eased(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private func draw(_ image: NSImage, fromTop top: CGFloat, to end: CGFloat,
                      offset: CGFloat = 0, opacity: CGFloat = 1) {
        let start = max(0, top)
        let finish = min(bounds.height, end)
        guard finish > start, opacity > 0 else { return }
        image.draw(in: CGRect(x: 0, y: start + offset, width: bounds.width, height: finish - start),
                   from: CGRect(x: 0, y: image.size.height - finish, width: image.size.width, height: finish - start),
                   operation: .sourceOver, fraction: opacity, respectFlipped: true, hints: nil)
    }

    private final class ProgressAnimation: NSAnimation {
        weak var owner: SyntaxFoldingTransitionView?
        override var currentProgress: NSAnimation.Progress {
            didSet {
                owner?.progress = CGFloat(currentProgress)
                owner?.needsDisplay = true
            }
        }
    }
}
#endif
