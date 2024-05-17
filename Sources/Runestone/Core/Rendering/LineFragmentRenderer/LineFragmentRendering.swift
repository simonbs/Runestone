import CoreGraphics

protocol LineFragmentRendering: Equatable {
    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    )
}

extension LineFragmentRendering {
    func isEqual(to other: any LineFragmentRendering) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}
