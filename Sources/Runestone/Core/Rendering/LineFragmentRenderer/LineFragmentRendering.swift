import CoreGraphics

protocol LineFragmentRendering {
    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    )
}
