import UIKit

/// A complete syntax highlight style applied to a captured range.
///
/// Unlike the individual styling callbacks on ``Theme``, a complete style replaces
/// styling from enclosing captures. This allows an inner capture to restore a regular
/// font or clear a background or shadow. It does not change unrelated attributes such
/// as paragraph layout or kerning.
public struct HighlightStyle {
    /// Foreground color, or `nil` to use ``Theme/textColor``.
    public var textColor: UIColor?
    /// Font including its weight and traits, or `nil` to use ``Theme/font``.
    public var font: UIFont?
    /// Token background color, or `nil` to clear the background.
    public var backgroundColor: UIColor?
    /// Text shadow, or `nil` to clear the shadow.
    public var shadow: NSShadow?

    /// Creates a complete style. An empty style restores the theme's default text appearance.
    public init(textColor: UIColor? = nil,
                font: UIFont? = nil,
                backgroundColor: UIColor? = nil,
                shadow: NSShadow? = nil) {
        self.textColor = textColor
        self.font = font
        self.backgroundColor = backgroundColor
        self.shadow = shadow
    }
}
