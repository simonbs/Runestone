import UIKit

final class BlockCaretView: UILabel {
    override var isHidden: Bool {
        didSet {
            if isHidden { layer.removeAnimation(forKey: "blink") }
        }
    }

    init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        clipsToBounds = true
        textAlignment = .center
        lineBreakMode = .byClipping
    }

    required init?(coder: NSCoder) { nil }

    func update(frame: CGRect, glyph: String?, font: UIFont, color: UIColor) {
        let needsBlink = isHidden || self.frame != frame || text != glyph
        self.frame = frame
        self.font = font
        text = glyph
        let fill = color.withAlphaComponent(1)
        backgroundColor = fill
        textColor = Self.contrastColor(for: fill)
        isHidden = false
        if needsBlink {
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [1, 1, 0, 0, 1]
            animation.keyTimes = [0, 0.5, 0.65, 0.85, 1]
            animation.duration = 1
            animation.repeatCount = .infinity
            layer.add(animation, forKey: "blink")
        }
    }

    private static func contrastColor(for color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return .white }
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        // White reads more clearly on the standard blue caret.
        if luminance <= 0.24, blue > green, green >= red, blue - red > 0.25 {
            return .white
        }
        return luminance > 0.179 ? .black : .white
    }
}
