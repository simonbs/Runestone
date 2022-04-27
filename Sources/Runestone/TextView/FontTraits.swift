import Foundation

/// Traits to be applied to a font.
public struct FontTraits: OptionSet {
    /// Attribute creating a bold font.
    public static let bold = FontTraits(rawValue: 1 << 0)
    /// Attribute creating an italic font.
    public static let italic = FontTraits(rawValue: 1 << 1)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
