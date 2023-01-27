#if os(macOS)
import AppKit
#endif
import CoreGraphics
#if os(iOS)
import UIKit
#endif

/// Fonts and colors to be used by a `TextView`.
public protocol Theme: AnyObject {
    /// Default font of text in the text view.
    var font: MultiPlatformFont { get }
    /// Default color of text in the text view.
    var textColor: MultiPlatformColor { get }
    /// Background color of the gutter containing line numbers.
    var gutterBackgroundColor: MultiPlatformColor { get }
    /// Color of the hairline next to the gutter containing line numbers.
    var gutterHairlineColor: MultiPlatformColor { get }
    /// Width of the hairline next to the gutter containing line numbers.
    var gutterHairlineWidth: CGFloat { get }
    /// Color of the line numbers in the gutter.
    var lineNumberColor: MultiPlatformColor { get }
    /// Font of the line nubmers in the gutter.
    var lineNumberFont: MultiPlatformFont { get }
    /// Background color of the selected line.
    var selectedLineBackgroundColor: MultiPlatformColor { get }
    /// Color of the line number of the selected line.
    var selectedLinesLineNumberColor: MultiPlatformColor { get }
    /// Background color of the gutter for selected lines.
    var selectedLinesGutterBackgroundColor: MultiPlatformColor { get }
    /// Color of invisible characters, i.e. dots, spaces and line breaks.
    var invisibleCharactersColor: MultiPlatformColor { get }
    /// Color of the hairline next to the page guide.
    var pageGuideHairlineColor: MultiPlatformColor { get }
    /// Background color of the page guide.
    var pageGuideBackgroundColor: MultiPlatformColor { get }
    /// Background color of marked text. Text will be marked when writing certain languages, for example Chinese and Japanese.
    var markedTextBackgroundColor: MultiPlatformColor { get }
    /// Corner radius of the background of marked text. Text will be marked when writing certain languages, for example Chinese and Japanese.
    /// A value of zero or less means that the background will not have rounded corners. Defaults to 0.
    var markedTextBackgroundCornerRadius: CGFloat { get }
    /// Color of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func textColor(for highlightName: String) -> MultiPlatformColor?
    /// Font of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func font(for highlightName: String) -> MultiPlatformFont?
    /// Traits of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func fontTraits(for highlightName: String) -> FontTraits
    /// Shadow of text matching the capture sequence.
    ///
    /// See <doc:CreatingATheme> for more information on higlight names.
    func shadow(for highlightName: String) -> NSShadow?
#if compiler(>=5.7) && os(iOS)
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
#endif
}

public extension Theme {
    var gutterHairlineWidth: CGFloat {
        #if os(iOS)
        return 1 / UIScreen.main.scale
        #else
        return 1 / NSScreen.main!.backingScaleFactor
        #endif
    }

    var pageGuideHairlineWidth: CGFloat {
        #if os(iOS)
        return 1 / UIScreen.main.scale
        #else
        return 1 / NSScreen.main!.backingScaleFactor
        #endif
    }

    var markedTextBackgroundCornerRadius: CGFloat {
        return 0
    }

    func font(for highlightName: String) -> MultiPlatformFont? {
        return nil
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        return []
    }

    func shadow(for highlightName: String) -> NSShadow? {
        return nil
    }

#if compiler(>=5.7) && os(iOS)
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
#endif
}
