import _RunestoneObservation
import QuartzCore
#if os(iOS)
import UIKit
#endif

@RunestoneObserver
final class LineFragmentLayer<
    LineType: Line,
    LineFragmentRendererType: LineFragmentRendering
>: CALayer, ReusableValue {
    var line: LineType? {
        didSet {
            if line != oldValue {
                setNeedsDisplay()
            }
        }
    }
    var lineFragment: LineType.LineFragmentType? {
        didSet {
            if lineFragment != oldValue {
                setNeedsDisplay()
            }
        }
    }
    var renderer: LineFragmentRendererType? {
        didSet {
            if renderer != oldValue {
                observeNeedsDisplay()
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

    private var needsDisplayObservation: Observation?

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

private extension LineFragmentLayer {
    private func observeNeedsDisplay() {
        needsDisplayObservation?.cancel()
        needsDisplayObservation = nil
        guard let renderer else {
            return
        }
        needsDisplayObservation = observe(renderer.needsDisplay) { [weak self] oldValue, newValue in
            if newValue != oldValue && newValue {
                self?.setNeedsDisplay()
            }
        }
    }
}
