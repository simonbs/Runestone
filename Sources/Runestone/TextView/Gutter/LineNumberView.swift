#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

final class LineNumberView: MultiPlatformView, ReusableView {
    var textColor: MultiPlatformColor = .black {
        didSet {
            if textColor != oldValue {
                setNeedsDisplay()
            }
        }
    }
    var font: MultiPlatformFont = .systemFont(ofSize: 14) {
        didSet {
            if font != oldValue {
                setNeedsDisplay()
            }
        }
    }
    var text: String? {
        didSet {
            if text != oldValue {
                setNeedsDisplay()
            }
        }
    }

    #if os(iOS)
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        _drawRect()
    }
    #else
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        _drawRect()
    }
    #endif
}

private extension LineNumberView {
    private func _drawRect() {
        guard let text = text as? NSString else {
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let size = text.size(withAttributes: attributes)
        let offset = CGPoint(x: bounds.width - size.width, y: (bounds.height - size.height) / 2)
        text.draw(at: offset)
    }
}
