import UIKit

/// Syntax highlights a string.
///
/// An instance of `StringSyntaxHighlighter` can be used to syntax highlight a string without needing to create a `TextView`.
public final class StringSyntaxHighlighter {
    /// The theme to use when syntax highlighting the text.
    public var theme: Theme
    /// The language to use when parsing the text.
    public var language: TreeSitterLanguage
    /// Object that can provide embedded languages on demand. A strong reference will be stored to the language provider.
    public var languageProvider: TreeSitterLanguageProvider?
    /// The number of points by which to adjust kern.
    ///
    /// The default value is 0 meaning that kerning is disabled.
    public var kern: CGFloat = 0
    /// The tab length determines the width of the tab measured in space characers.
    ///
    /// The default value is 4 meaning that a tab is four spaces wide.
    public var tabLength: Int = 4
    /// The line-height is multiplied with the value.
    public var lineHeightMultiplier: CGFloat = 1

    /// Creates an object that can syntax highlight a text.
    /// - Parameters:
    ///   - theme: The theme to use when syntax highlighting the text.
    ///   - language: The language to use when parsing the text
    ///   - languageProvider: Object that can provide embedded languages on demand. A strong reference will be stored to the language provider..
    public init(
        theme: Theme = DefaultTheme(),
        language: TreeSitterLanguage,
        languageProvider: TreeSitterLanguageProvider? = nil
    ) {
        self.theme = theme
        self.language = language
        self.languageProvider = languageProvider
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Syntax highlights the text using the configured syntax highlighter.
    /// - Parameter text: The text to be syntax highlighted.
    /// - Returns: An attributed string containing the syntax highlighted text.
    public func syntaxHighlight(_ text: String) -> NSAttributedString {
        let mutableString = NSMutableString(string: text)
        let stringView = StringView(string: mutableString)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let languageMode = TreeSitterLanguageMode(language: language, languageProvider: languageProvider)
        let internalLanguageMode = languageMode.makeInternalLanguageMode(
            stringView: stringView,
            lineManager: lineManager
        )
        internalLanguageMode.parse(mutableString)
        let tabWidth = TabWidthMeasurer.tabWidth(tabLength: tabLength, font: theme.font)
        let mutableAttributedString = NSMutableAttributedString(string: text)
        let defaultAttributes = DefaultStringAttributes(
            textColor: theme.textColor,
            font: theme.font,
            kern: kern,
            tabWidth: tabWidth
        )
        defaultAttributes.apply(to: mutableAttributedString)
        applyLineHeightMultiplier(to: mutableAttributedString)
        let byteRange = ByteRange(from: 0, to: text.byteCount)
        let syntaxHighlighter = internalLanguageMode.createLineSyntaxHighlighter()
        syntaxHighlighter.theme = theme
        let syntaxHighlighterInput = LineSyntaxHighlighterInput(
            attributedString: mutableAttributedString,
            byteRange: byteRange
        )
        syntaxHighlighter.syntaxHighlight(syntaxHighlighterInput)
        return mutableAttributedString
    }
}

private extension StringSyntaxHighlighter {
    private func applyLineHeightMultiplier(to attributedString: NSMutableAttributedString) {
        let scaledLineHeight = theme.font.totalLineHeight * lineHeightMultiplier
        let mutableParagraphStyle = getMutableParagraphStyle(from: attributedString)
        mutableParagraphStyle.lineSpacing = scaledLineHeight - theme.font.totalLineHeight
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.beginEditing()
        attributedString.removeAttribute(.paragraphStyle, range: range)
        attributedString.addAttribute(.paragraphStyle, value: mutableParagraphStyle, range: range)
        attributedString.endEditing()
    }

    private func getMutableParagraphStyle(
        from attributedString: NSMutableAttributedString
    ) -> NSMutableParagraphStyle {
        guard let attributeValue = attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) else {
            return NSMutableParagraphStyle()
        }
        guard let paragraphStyle = attributeValue as? NSParagraphStyle else {
            fatalError("Expected .paragraphStyle attribute to be instance of NSParagraphStyle")
        }
        guard let mutableParagraphStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle else {
            fatalError("Expected mutableCopy() to return an instance of NSMutableParagraphStyle")
        }
        return mutableParagraphStyle
    }
}
