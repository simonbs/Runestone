import Foundation

/// Language mode with no syntax highlighting.
///
/// This language mode is used by default when creating a new ``TextView``.
public final class PlainTextLanguageMode {
    public init() {}
}

extension PlainTextLanguageMode: LanguageMode {
    func makeInternalLanguageMode(stringView: StringView, lineManager: LineManager) -> InternalLanguageMode {
        return PlainTextInternalLanguageMode()
    }
}
