import Foundation

/// Encapsulates the bare informations needed to do syntax highlighting in a text view.
///
/// It is recommended to create an instance of `TextViewState` on a background queue and pass it to a <doc:TextView> instead of setting the text, theme and language on the text view separately.
public final class TextViewState {
    let stringView: StringView
    let theme: Theme
    let lineManager: LineManager
    let languageMode: InternalLanguageMode

    /// Indent strategy detected in the text.
    ///
    /// The information provided by the detected strategy can be used to update the ``TextView/indentStrategy`` on the text view to align with the existing strategy in a text.
    public private(set) var detectedIndentStrategy: DetectedIndentStrategy = .unknown

    /// Creates state that can be passed to an instance of <doc:TextView>.
    /// - Parameters:
    ///   - text: The text to display in the text view.
    ///   - theme: The theme to use when syntax highlighting the text.
    ///   - language: The language to use when parsing the text.
    ///   - languageProvider: Object that can provide embedded languages on demand. A strong reference will be stored to the language provider.
    public init(text: String, theme: Theme, language: TreeSitterLanguage, languageProvider: TreeSitterLanguageProvider? = nil) {
        self.theme = theme
        self.stringView = StringView(string: NSMutableString(string: text))
        self.lineManager = LineManager(stringView: stringView)
        self.languageMode = TreeSitterInternalLanguageMode(
            language: language.internalLanguage,
            languageProvider: languageProvider,
            stringView: stringView,
            lineManager: lineManager)
        prepare(with: text)
    }

    /// Creates state that can be passed to an instance of <doc:TextView>.
    ///
    /// The created theme will use an instance of <doc:PlainTextLanguageMode>.
    /// - Parameters:
    ///   - text: The text to display in the text view.
    ///   - theme: The theme to use when syntax highlighting the text.
    public init(text: String, theme: Theme) {
        self.theme = theme
        self.stringView = StringView(string: NSMutableString(string: text))
        self.lineManager = LineManager(stringView: stringView)
        self.languageMode = PlainTextInternalLanguageMode()
        prepare(with: text)
    }
}

private extension TextViewState {
    private func prepare(with text: String) {
        let nsString = text as NSString
        lineManager.estimatedLineHeight = theme.font.totalLineHeight
        lineManager.rebuild(from: nsString)
        languageMode.parse(nsString)
        detectedIndentStrategy = languageMode.detectIndentStrategy()
    }
}
