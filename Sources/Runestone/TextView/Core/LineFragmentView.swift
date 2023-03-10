#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class LineFragmentView: FlippedView, ReusableView {
    var renderer: Renderer? {
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
        renderer?.render()
    }

    func prepareForReuse() {
        renderer = nil
    }
    #else
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        renderer?.render()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        renderer = nil
    }
    #endif
}
