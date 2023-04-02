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
    override var frame: CGRect {
        didSet {
            if frame != oldValue {
                setNeedsDisplay()
            }
        }
    }

    init() {
        super.init(frame: .zero)
        #if os(iOS)
        isOpaque = false
        #else
        layer?.isOpaque = false
        #endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        guard let text else {
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        let offset = CGPoint(x: bounds.width - size.width, y: (bounds.height - size.height) / 2)
        attributedString.draw(at: offset)
    }
}
