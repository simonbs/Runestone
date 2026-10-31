import Foundation

/// Vertical placement shared by caret and text drawing in a line fragment.
public struct LineFragmentVerticalGeometry {
    /// Creates the baseline geometry for a fragment.
    public init(baseHeight: CGFloat, scaledHeight: CGFloat, descent: CGFloat) {
        self.baseHeight = baseHeight
        self.scaledHeight = scaledHeight
        self.descent = descent
    }

    let baseHeight: CGFloat
    let scaledHeight: CGFloat
    let descent: CGFloat

    /// Offset of the unscaled text box from the top of the fragment.
    public var textTop: CGFloat {
        (scaledHeight - baseHeight) / 2
    }

    /// Baseline measured from the top of the fragment.
    public var topDownBaseline: CGFloat {
        scaledHeight - descent - textTop
    }

    /// Baseline measured from the bottom of the fragment.
    public var coreTextBaseline: CGFloat {
        descent + textTop
    }
}
