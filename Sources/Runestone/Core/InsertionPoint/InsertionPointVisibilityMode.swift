/// Visibility mode for the insertion point.
///
/// Specifies when the insertion point is visible. The default visiblity is ``InsertionPointVisibilityMode/whenMovingAndFarAway``.
public enum InsertionPointVisibilityMode {
    /// Always visible.
    ///
    /// The insertion point is visible when editing text and it is always visible when it is being moved.
    case always
    /// Hidden when moving the insertion point unless it is far away.
    ///
    /// The insertion point is visible when editing text but it is hidden when moving the insertion point unless it is far away.
    case hiddenWhenMovingUnlessFarAway
}
