import Foundation

/// Encapsulates the bare informations needed to do syntax highlighting in a text view.
///
/// It is recommended to create an instance of `TextViewState` on a background queue and pass it to a ``TextView`` instead of setting the text, theme and language on the text view separately.
public final class TextViewState {
    let stringView: StringView
    let theme: Theme
    let lineManager: LineManager
    let languageModeState: LanguageModeState

    /// Indent strategy detected in the text.
    ///
    /// The information provided by the detected strategy can be used to update the ``TextView/indentStrategy`` on the text view to align with the existing strategy in a text.
    public let detectedIndentStrategy: DetectedIndentStrategy = .unknown

    /// Line endings detected in the dtext.
    ///
    /// The information pvoided by the detected line endings can be used to update the ``TextView/lineEndings`` on the text view to align with the existing line endings in a text.
    ///
    /// The value is `nil` if the line ending cannot be detected.
    public let detectedLineEndings: LineEnding?

    /// Creates state that can be passed to an instance of ``TextView``.
    /// - Parameters:
    ///   - text: The text to display in the text view.
    ///   - theme: The theme to use when syntax highlighting the text.
    ///   - language: The language to use when parsing the text.
    ///   - languageProvider: Object that can provide embedded languages on demand. A strong reference will be stored to the language provider.
    public convenience init(
        text: String,
        theme: Theme = DefaultTheme(),
        language: TreeSitterLanguage,
        languageProvider: TreeSitterLanguageProvider? = nil
    ) {
        let string = NSMutableString(string: text)
        let stringView = StringView(string: string)
        let lineManager = Self.makeLineManager(stringView: stringView, theme: theme)
        let parser = TreeSitterParser()
        parser.language = language.languagePointer
        let tree = parser.parse(string)
        let languageModeState: LanguageModeState = .treeSitter(.init(
            language: language.internalLanguage,
            languageProvider: languageProvider,
            parser: parser,
            tree: tree
        ))
        let indentStrategy = Self.detectIndentStrategy(string: string, lineManager: lineManager, tree: tree)
        self.init(
            stringView: stringView,
            lineManager: lineManager,
            theme: theme,
            languageModeState: languageModeState,
            indentStrategy: indentStrategy
        )
    }

    /// Creates state that can be passed to an instance of ``TextView``.
    ///
    /// The created theme will use an instance of ``PlainTextLanguageMode``.
    /// - Parameters:
    ///   - text: The text to display in the text view.
    ///   - theme: The theme to use when syntax highlighting the text.
    public convenience init(text: String, theme: Theme = DefaultTheme()) {
        let stringView = StringView(string: NSMutableString(string: text))
        let lineManager = Self.makeLineManager(stringView: stringView, theme: theme)
        self.init(
            stringView: stringView,
            lineManager: lineManager,
            theme: theme,
            languageModeState: .plainText,
            indentStrategy: .unknown
        )
    }

    private init(
        stringView: StringView,
        lineManager: LineManager,
        theme: Theme,
        languageModeState: LanguageModeState,
        indentStrategy: DetectedIndentStrategy
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.theme = theme
        self.languageModeState = languageModeState
        let lineEndingDetector = LineEndingDetector(stringView: stringView, lineManager: lineManager)
        detectedLineEndings = lineEndingDetector.detect()
    }
}

private extension TextViewState {
    static func makeLineManager(stringView: StringView, theme: Theme) -> LineManager {
        let lineManager = LineManager(stringView: stringView)
        lineManager.estimatedLineHeight = theme.font.totalLineHeight
        lineManager.rebuild()
        return lineManager
    }

    static func detectIndentStrategy(string: NSString, lineManager: LineManager, tree: TreeSitterTree?) -> DetectedIndentStrategy {
        guard let tree else {
            return .unknown
        }
        let detector = TreeSitterIndentStrategyDetector(string: string, lineManager: lineManager, tree: tree)
        return detector.detect()
    }
}
