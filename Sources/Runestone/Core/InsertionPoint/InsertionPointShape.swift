import Foundation

/// Shape of the insertion point.
@available(iOS, unavailable)
public enum InsertionPointShape {
    /// Vertical bar shape.
    ///
    /// The bar has a fixed width and a height that matches the character it is at.
    ///
    /// This is the default shape of the insertion point.
    case verticalBar
    /// Underline shape.
    ///
    /// This line has the same width as the character it is on and a fixed height.
    case underline
    /// Square block shape.
    ///
    /// The block is the same width and height as the character it is on.
    case block
}
