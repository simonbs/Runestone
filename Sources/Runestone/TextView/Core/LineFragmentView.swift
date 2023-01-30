#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

final class LineFragmentView: FlippedView, ReusableView {
    var renderer: LineFragmentRenderer? {
        didSet {
            if renderer !== oldValue {
                setNeedsDisplay()
            }
        }
    }
    override var frame: CGRect {
        didSet {
            if frame.size != oldValue.size {
                setNeedsDisplay()
            }
        }
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        #if os(iOS)
        isUserInteractionEnabled = false
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

    #if os(iOS)
    func prepareForReuse() {
        _prepareForReuse()
    }
    #else
    override func prepareForReuse() {
        super.prepareForReuse()
        _prepareForReuse()
    }
    #endif
}

private extension LineFragmentView {
    private func _drawRect() {
        if let context = UIGraphicsGetCurrentContext() {
            renderer?.draw(to: context, inCanvasOfSize: bounds.size)
        }
    }

    private func _prepareForReuse() {
        renderer = nil
    }
}
