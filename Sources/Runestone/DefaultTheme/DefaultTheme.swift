import UIKit

public final class DefaultTheme: Runestone.Theme {
    public let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let backgroundColor = UIColor(themeColorNamed: "background")
    public let textColor = UIColor(themeColorNamed: "foreground")
    public let gutterBackgroundColor = UIColor(themeColorNamed: "background")
    public let gutterHairlineColor = UIColor(themeColorNamed: "background")
    public let lineNumberColor = UIColor(themeColorNamed: "line_number")
    public let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let selectedLineBackgroundColor = UIColor(themeColorNamed: "current_line")
    public let selectedLinesLineNumberColor = UIColor(themeColorNamed: "line_number_current_line")
    public let selectedLinesGutterBackgroundColor = UIColor(themeColorNamed: "background")
    public let invisibleCharactersColor = UIColor(themeColorNamed: "invisible_characters")
    public let pageGuideHairlineColor = UIColor(themeColorNamed: "background")
    public let pageGuideBackgroundColor = UIColor(themeColorNamed: "background")
    public let markedTextBackgroundColor = UIColor(themeColorNamed: "marked_text")
    public let selectionColor = UIColor(themeColorNamed: "selection")

    public init() {}

    public func textColor(for highlightName: String) -> UIColor? {
        guard let highlightName = HighlightName(highlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return UIColor(themeColorNamed: "comment")
        case .constantBuiltin:
            return UIColor(themeColorNamed: "constant_builtin")
        case .constantCharacter:
            return UIColor(themeColorNamed: "constant_character")
        case .constructor:
            return UIColor(themeColorNamed: "constructor")
        case .function:
            return UIColor(themeColorNamed: "function")
        case .keyword:
            return UIColor(themeColorNamed: "keyword")
        case .number:
            return UIColor(themeColorNamed: "number")
        case .property:
            return UIColor(themeColorNamed: "property")
        case .string:
            return UIColor(themeColorNamed: "string")
        case .type:
            return UIColor(themeColorNamed: "type")
        case .variable:
            return nil
        case .variableBuiltin:
            return UIColor(themeColorNamed: "variable_builtin")
        case .operator:
            return UIColor(themeColorNamed: "operator")
        case .punctuation:
            return UIColor(themeColorNamed: "punctuation")
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
