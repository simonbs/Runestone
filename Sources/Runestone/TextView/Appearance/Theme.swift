import UIKit

/// Fonts and colors to be used by a `TextView`.
public protocol Theme: AnyObject {
    /// Default font of text in the text view.
    var font: UIFont { get }
    /// Default color of text in the text view.
    var textColor: UIColor { get }
    /// Background color of the gutter containing line numbers.
    var gutterBackgroundColor: UIColor { get }
    /// Color of the hairline next to the gutter containing line numbers.
    var gutterHairlineColor: UIColor { get }
    /// Width of the hairline next to the gutter containing line numbers.
    var gutterHairlineWidth: CGFloat { get }
    /// Color of the line numbers in the gutter.
    var lineNumberColor: UIColor { get }
    /// Font of the line nubmers in the gutter.
    var lineNumberFont: UIFont { get }
    /// Background color of the selected line.
    var selectedLineBackgroundColor: UIColor { get }
    /// Color of the line number of the selected line.
    var selectedLinesLineNumberColor: UIColor { get }
    /// Background color of the gutter for selected lines.
    var selectedLinesGutterBackgroundColor: UIColor { get }
    /// Color of invisible characters, i.e. dots, spaces and line breaks.
    var invisibleCharactersColor: UIColor { get }
    /// Color of the hairline next to the page guide.
    var pageGuideHairlineColor: UIColor { get }
    /// Width of the hairline next to the page guide.
    var pageGuideHairlineWidth: CGFloat { get }
    /// Background color of the page guide.
    var pageGuideBackgroundColor: UIColor { get }
    /// Background color of marked text. Text will be marked when writing certain languages, for example Chinese and Japanese.
    var markedTextBackgroundColor: UIColor { get }
    /// Corner radius of the background of marked text. Text will be marked when writing certain languages, for example Chinese and Japanese.
    /// A value of zero or less means that the background will not have rounded corners. Defaults to 0.
    var markedTextBackgroundCornerRadius: CGFloat { get }
    /// Color of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func textColor(for highlightName: String) -> UIColor?
    /// Font of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func font(for highlightName: String) -> UIFont?
    /// Traits of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func fontTraits(for highlightName: String) -> FontTraits
    /// Shadow of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func shadow(for highlightName: String) -> NSShadow?
    /// Highlighted range for a text range matching a search query.
    ///
    /// This function is called when highlighting a search result that was found using the standard find/replace interaction enabled using <doc:TextView/isFindInteractionEnabled>.
    ///
    /// Return `nil` to prevent highlighting the range.
    /// - Parameters:
    ///   - foundTextRange: The text range matching a search query.
    ///   - style: Style used to decorate the text.
    /// - Returns: The object used for highlighting the provided text range, or `nil` if the range should not be highlighted.
    @available(iOS 16, *)
    func highlightedRange(forFoundTextRange foundTextRange: NSRange, ofStyle style: UITextSearchFoundTextStyle) -> HighlightedRange?
}

public extension Theme {
    var gutterHairlineWidth: CGFloat {
        hairlineLength
    }

    var pageGuideHairlineWidth: CGFloat {
        hairlineLength
    }

    var markedTextBackgroundCornerRadius: CGFloat {
        0
    }

    func font(for highlightName: String) -> UIFont? {
        nil
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        []
    }

    func shadow(for highlightName: String) -> NSShadow? {
        nil
    }

    @available(iOS 16, *)
    func highlightedRange(forFoundTextRange foundTextRange: NSRange, ofStyle style: UITextSearchFoundTextStyle) -> HighlightedRange? {
        switch style {
        case .found:
            return HighlightedRange(range: foundTextRange, color: .systemYellow.withAlphaComponent(0.2))
        case .highlighted:
            return HighlightedRange(range: foundTextRange, color: .systemYellow)
        case .normal:
            return nil
        @unknown default:
            return nil
        }
    }
}
