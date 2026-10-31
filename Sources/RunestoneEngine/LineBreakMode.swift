import Foundation

/// Line wrapping policy for the text view and Core Text typesetter.
public enum LineBreakMode: Int, CaseIterable {
    /// Wrap at word boundaries.
    case byWordWrapping = 0
    /// Wrap at character boundaries.
    case byCharWrapping = 1
}
