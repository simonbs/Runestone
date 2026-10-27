import UIKit

/// Default theme used by Runestone when no other theme has been set.
public final class DefaultTheme: Runestone.Theme {
    public let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = UIColor(themeColorNamed: "foreground")
    public let gutterBackgroundColor = UIColor(themeColorNamed: "gutter_background")
    public let gutterHairlineColor = UIColor(themeColorNamed: "gutter_hairline")
    public let lineNumberColor = UIColor(themeColorNamed: "line_number")
    public let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let selectedLineBackgroundColor = UIColor(themeColorNamed: "current_line")
    public let selectedLinesLineNumberColor = UIColor(themeColorNamed: "line_number_current_line")
    public let selectedLinesGutterBackgroundColor = UIColor(themeColorNamed: "gutter_background")
    public let invisibleCharactersColor = UIColor(themeColorNamed: "invisible_characters")
    public let pageGuideHairlineColor = UIColor(themeColorNamed: "page_guide_hairline")
    public let pageGuideBackgroundColor = UIColor(themeColorNamed: "page_guide_background")
    public let markedTextBackgroundColor = UIColor(themeColorNamed: "marked_text")
    public let selectionColor = UIColor(themeColorNamed: "selection")

    /// Shared immutable theme used when no custom theme is supplied.
    ///
    /// Its colors adapt to the appearance of the interface where they are displayed.
    public static let shared = DefaultTheme()

    public init() {}

    // Keep asset colors dynamic; resolving them here would freeze the current appearance.
    private enum TokenColors {
        static let comment = UIColor(themeColorNamed: "comment")
        static let constantBuiltin = UIColor(themeColorNamed: "constant_builtin")
        static let constantCharacter = UIColor(themeColorNamed: "constant_character")
        static let constructor = UIColor(themeColorNamed: "constructor")
        static let function = UIColor(themeColorNamed: "function")
        static let keyword = UIColor(themeColorNamed: "keyword")
        static let number = UIColor(themeColorNamed: "number")
        static let property = UIColor(themeColorNamed: "property")
        static let `string` = UIColor(themeColorNamed: "string")
        static let `type` = UIColor(themeColorNamed: "type")
        static let variableBuiltin = UIColor(themeColorNamed: "variable_builtin")
        static let `operator` = UIColor(themeColorNamed: "operator")
        static let punctuation = UIColor(themeColorNamed: "punctuation")
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func textColor(for highlightName: String) -> UIColor? {
        guard let highlightName = HighlightName(highlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return TokenColors.comment
        case .constantBuiltin:
            return TokenColors.constantBuiltin
        case .constantCharacter:
            return TokenColors.constantCharacter
        case .constructor:
            return TokenColors.constructor
        case .function:
            return TokenColors.function
        case .keyword:
            return TokenColors.keyword
        case .number:
            return TokenColors.number
        case .property:
            return TokenColors.property
        case .string:
            return TokenColors.string
        case .type:
            return TokenColors.type
        case .variable:
            return nil
        case .variableBuiltin:
            return TokenColors.variableBuiltin
        case .operator:
            return TokenColors.operator
        case .punctuation:
            return TokenColors.punctuation
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

    @available(iOS 16.0, *)
    public func highlightedRange(forFoundTextRange foundTextRange: NSRange, ofStyle style: UITextSearchFoundTextStyle) -> HighlightedRange? {
        switch style {
        case .found:
            let color = UIColor(themeColorNamed: "search_match_found")
            return HighlightedRange(range: foundTextRange, color: color, cornerRadius: 2)
        case .highlighted:
            let color = UIColor(themeColorNamed: "search_match_highlighted")
            return HighlightedRange(range: foundTextRange, color: color, cornerRadius: 2)
        case .normal:
            return nil
        @unknown default:
            return nil
        }
    }
}

private extension UIColor {
    convenience init(themeColorNamed name: String) {
        self.init(named: "theme_" + name, in: .module, compatibleWith: nil)!
    }
}
