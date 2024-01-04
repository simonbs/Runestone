import CoreGraphics

struct CompositeLineFragmentRenderer: LineFragmentRendering {
    private let renderers: [LineFragmentRendering]

    init(renderers: [LineFragmentRendering]) {
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
}
