import UIKit

final class LineFragmentView: UIView, ReusableView {
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

    private var isRenderInvalid = true

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if let context = UIGraphicsGetCurrentContext() {
            renderer?.draw(to: context, inCanvasOfSize: bounds.size)
        }
    }

    func prepareForReuse() {
        renderer = nil
    }
}
