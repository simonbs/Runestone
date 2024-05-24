import CoreGraphics

protocol LineFragmentRendering: Equatable {
    var needsDisplay: Bool { get }
    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    )
}

extension LineFragmentRendering {
    var needsDisplay: Bool {
        false
    }
}

extension LineFragmentRendering {
    func isEqual(to other: any LineFragmentRendering) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}
