import CoreGraphics

protocol LineFragmentRendering: Equatable {
    associatedtype LineType: Line
    func render(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    )
}
