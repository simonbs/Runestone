import _RunestoneObservation
import CoreGraphics

@RunestoneObserver @RunestoneObservable
final class CompositeLineFragmentRenderer: LineFragmentRendering {
    private(set) var needsDisplay = false

    private let renderers: [any LineFragmentRendering]

    init(renderers: [any LineFragmentRendering]) {
        self.renderers = renderers
        observeNeedsDisplay(of: renderers)
    }

    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        needsDisplay = false
        for renderer in renderers {
            renderer.render(lineFragment, in: line, to: context)
        }
    }

    static func ==(lhs: CompositeLineFragmentRenderer, rhs: CompositeLineFragmentRenderer) -> Bool {
        guard lhs.renderers.count == rhs.renderers.count else {
            return false
        }
        for (lhsRenderer, rhsRenderer) in zip(lhs.renderers, rhs.renderers) {
            if !lhsRenderer.isEqual(to: rhsRenderer) {
                return false
            }
        }
        return true
    }
}

private extension CompositeLineFragmentRenderer {
    private func observeNeedsDisplay(of renderers: [any LineFragmentRendering]) {
        for renderer in renderers {
            observe(renderer.needsDisplay) { [weak self] oldValue, newValue in
                if newValue != oldValue && newValue {
                    self?.needsDisplay = true
                }
            }
        }
    }
}
