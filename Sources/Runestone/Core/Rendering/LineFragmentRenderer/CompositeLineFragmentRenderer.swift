import CoreGraphics

struct CompositeLineFragmentRenderer: LineFragmentRendering {
    private let renderers: [any LineFragmentRendering]

    init(renderers: [any LineFragmentRendering]) {
        self.renderers = renderers
    }

    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
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
