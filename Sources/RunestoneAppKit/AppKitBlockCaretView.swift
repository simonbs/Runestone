#if canImport(AppKit)
import AppKit

final class AppKitBlockCaretView: NSView {
    private var fill = NSColor.textInsertionPointColor
    private var glyph: String?
    private var font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

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

    func update(frame: NSRect, glyph: String?, font: NSFont, color: NSColor) {
        let color = color.withAlphaComponent(1)
        let restartBlink = isHidden || self.frame != frame || self.glyph != glyph
        if restartBlink || self.font != font || fill != color {
            self.frame = frame
            self.glyph = glyph
            self.font = font
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
        guard let glyph else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Self.contrastColor(for: fill)
        ]
        let text = NSAttributedString(string: glyph, attributes: attributes)
        let size = text.size()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: bounds).addClip()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
    }

    static func contrastColor(for color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        let contrastWithBlack = (luminance + 0.05) / 0.05
        let contrastWithWhite = 1.05 / (luminance + 0.05)
        // Favor white on saturated blue when it still has strong contrast.
        if contrastWithWhite >= 3.75, rgb.blueComponent > rgb.greenComponent,
           rgb.greenComponent >= rgb.redComponent, rgb.blueComponent - rgb.redComponent > 0.25 {
            return .white
        }
        return contrastWithBlack >= contrastWithWhite ? .black : .white
    }
}
#endif
