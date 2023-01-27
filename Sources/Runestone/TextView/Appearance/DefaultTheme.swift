/// Default theme used by Runestone when no other theme has been set.
public final class DefaultTheme: Runestone.Theme {
    public let font: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = MultiPlatformColor(themeColorNamed: "foreground")
    public let gutterBackgroundColor = MultiPlatformColor(themeColorNamed: "gutter_background")
    public let gutterHairlineColor = MultiPlatformColor(themeColorNamed: "gutter_hairline")
    public let lineNumberColor = MultiPlatformColor(themeColorNamed: "line_number")
    public let lineNumberFont: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let selectedLineBackgroundColor = MultiPlatformColor(themeColorNamed: "current_line")
    public let selectedLinesLineNumberColor = MultiPlatformColor(themeColorNamed: "line_number_current_line")
    public let selectedLinesGutterBackgroundColor = MultiPlatformColor(themeColorNamed: "gutter_background")
    public let invisibleCharactersColor = MultiPlatformColor(themeColorNamed: "invisible_characters")
    public let pageGuideHairlineColor = MultiPlatformColor(themeColorNamed: "page_guide_hairline")
    public let pageGuideBackgroundColor = MultiPlatformColor(themeColorNamed: "page_guide_background")
    public let markedTextBackgroundColor = MultiPlatformColor(themeColorNamed: "marked_text")
    public let selectionColor = MultiPlatformColor(themeColorNamed: "selection")

    public init() {}

    // swiftlint:disable:next cyclomatic_complexity
    public func textColor(for highlightName: String) -> MultiPlatformColor? {
        guard let highlightName = HighlightName(highlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return MultiPlatformColor(themeColorNamed: "comment")
        case .constantBuiltin:
            return MultiPlatformColor(themeColorNamed: "constant_builtin")
        case .constantCharacter:
            return MultiPlatformColor(themeColorNamed: "constant_character")
        case .constructor:
            return MultiPlatformColor(themeColorNamed: "constructor")
        case .function:
            return MultiPlatformColor(themeColorNamed: "function")
        case .keyword:
            return MultiPlatformColor(themeColorNamed: "keyword")
        case .number:
            return MultiPlatformColor(themeColorNamed: "number")
        case .property:
            return MultiPlatformColor(themeColorNamed: "property")
        case .string:
            return MultiPlatformColor(themeColorNamed: "string")
        case .type:
            return MultiPlatformColor(themeColorNamed: "type")
        case .variable:
            return nil
        case .variableBuiltin:
            return MultiPlatformColor(themeColorNamed: "variable_builtin")
        case .operator:
            return MultiPlatformColor(themeColorNamed: "operator")
        case .punctuation:
            return MultiPlatformColor(themeColorNamed: "punctuation")
        }
    }

    public func fontTraits(for highlightName: String) -> FontTraits {
        guard let highlightName = HighlightName(highlightName) else {
            return []
        }
        if highlightName == .keyword {
            return .bold
        } else {
            return []
        }
    }

#if compiler(>=5.7) && os(iOS)
    @available(iOS 16.0, *)
    public func highlightedRange(forFoundTextRange foundTextRange: NSRange, ofStyle style: UITextSearchFoundTextStyle) -> HighlightedRange? {
        switch style {
        case .found:
            let color = MultiPlatformColor(themeColorNamed: "search_match_found")
            return HighlightedRange(range: foundTextRange, color: color, cornerRadius: 2)
        case .highlighted:
            let color = MultiPlatformColor(themeColorNamed: "search_match_highlighted")
            return HighlightedRange(range: foundTextRange, color: color, cornerRadius: 2)
        case .normal:
            return nil
        @unknown default:
            return nil
        }
    }
#endif
}
