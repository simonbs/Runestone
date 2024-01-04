import QuartzCore
#if os(iOS)
import UIKit
#endif

final class LineFragmentLayer<LineType: Line>: CALayer, ReusableValue {
    var line: LineType?
    var lineFragment: LineType.LineFragmentType?
    var renderer: LineFragmentRendering?
    override var frame: CGRect {
        didSet {
            if frame.size != oldValue.size {
                setNeedsDisplay()
            }
        }
    }

    static func makeReusableValue() -> LineFragmentLayer {
        let layer = LineFragmentLayer()
        #if os(iOS)
        layer.contentsScale = UIScreen.main.scale
        #endif
        return layer
    }

    func prepareForReuse() {
        line = nil
        lineFragment = nil
        removeFromSuperlayer()
    }

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        if let line, let lineFragment {
            renderer?.render(lineFragment, in: line, to: ctx)
        }
    }
}
