import Foundation

/// Provide Tree-sitter languages on demand.
///
/// Some languages contain other embedded languages. For example, an HTML document can contain CSS and JavaScript.
/// When a ``TreeSitterLanguageMode`` encounters an embedded language, it expects that language to be provided on demand.
public protocol TreeSitterLanguageProvider: AnyObject {
    /// Called by ``TreeSitterLanguageMode`` when it encounters an embedded name.
    ///
    /// The provider is expected to load an return a language matching the name.
    ///
    /// When returning `nil` the text in the embedded language wll not be highlighted.
    ///
    /// - Returns: Language matching the name,
    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage?
}
