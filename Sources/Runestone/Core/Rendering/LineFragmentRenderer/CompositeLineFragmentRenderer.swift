import CoreGraphics

struct CompositeLineFragmentRenderer<LineType: Line>: LineFragmentRendering {
    private let renderers: [AnyLineFragmentRenderer<LineType>]

    init(renderers: [AnyLineFragmentRenderer<LineType>]) {
        self.renderers = renderers
    }

    func render(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        for renderer in renderers {
            renderer.render(lineFragment, in: line, to: context)
        }
    }
}
