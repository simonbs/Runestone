import Foundation

/// Language mode with no syntax highlighting.
///
/// This language mode is used by default when creating a new ``TextView``.
public final class PlainTextLanguageMode {
    /// Creates a plain text language mode that provides no syntax highlighting.
    public init() {}
}

extension PlainTextLanguageMode: LanguageMode {
    func makeInternalLanguageMode(stringView: StringView, lineManager: LineManager) -> InternalLanguageMode {
        PlainTextInternalLanguageMode()
    }
}
