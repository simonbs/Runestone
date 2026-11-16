#if canImport(AppKit)
import AppKit
import RunestoneEngine

final class AppKitBlockCaretView: NSView {
    private var fill = NSColor.textInsertionPointColor
    private var placement: LogicalLineLayoutController.Placement?

    override var isFlipped: Bool { true }

    override var isHidden: Bool {
        didSet {
            if isHidden { layer?.removeAnimation(forKey: "blink") }
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        isHidden = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(frame: NSRect, placement: LogicalLineLayoutController.Placement?, color: NSColor) {
        let color = color.withAlphaComponent(1)
        let restartBlink = isHidden || self.frame != frame
        if restartBlink || self.placement?.fragment !== placement?.fragment ||
            self.placement?.frame != placement?.frame || fill != color {
            self.frame = frame
            self.placement = placement
            fill = color
            needsDisplay = true
        }
        isHidden = false
        if restartBlink {
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            // Match the native indicator's one-second cycle and stepped fades.
            animation.values = [1, 0.75, 0.5, 0.25, 0, 0.25, 0.5, 0.75, 1]
            animation.keyTimes = [0, 0.5375, 0.575, 0.6125, 0.65, 0.8875, 0.925, 0.9625, 1]
            animation.calculationMode = .discrete
            animation.duration = 1
            animation.repeatCount = .infinity
            layer?.add(animation, forKey: "blink")
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        bounds.fill()
        guard let placement, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: bounds)
        // Mask the new ink with the already-shaped glyphs at their original baseline.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.saveGState()
        context.translateBy(x: placement.frame.minX - frame.minX, y: placement.frame.minY - frame.minY)
        LineFragmentRenderer.drawGlyphs(placement.fragment, in: context)
        context.restoreGState()
        context.setBlendMode(.sourceIn)
        context.setFillColor(Self.contrastColor(for: fill).cgColor)
        context.fill(bounds)
        context.endTransparencyLayer()
        context.restoreGState()
    }

    static func contrastColor(for color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        // Prefer white for the small caret glyph when it clears a 4:1 contrast ratio.
        // Otherwise black provides the stronger contrast.
        return 1.05 / (luminance + 0.05) >= 4 ? .white : .black
    }
}
#endif
