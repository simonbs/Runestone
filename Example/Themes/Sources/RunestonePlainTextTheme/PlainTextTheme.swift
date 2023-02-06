import Runestone
import RunestoneThemeCommon
import UIKit

public final class PlainTextTheme: EditorTheme {
    public let backgroundColor: UIColor = .white
    public let userInterfaceStyle: UIUserInterfaceStyle = .light

    public let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor: UIColor = .black

    public let gutterBackgroundColor: UIColor = .white
    public let gutterHairlineColor: UIColor = .white

    public let lineNumberColor: UIColor = .black.withAlphaComponent(0.5)
    public let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor: UIColor = .black.withAlphaComponent(0.07)
    public let selectedLinesLineNumberColor: UIColor = .black
    public let selectedLinesGutterBackgroundColor: UIColor = .black.withAlphaComponent(0.07)

    public let invisibleCharactersColor: UIColor = .black.withAlphaComponent(0.5)

    public let pageGuideHairlineColor: UIColor = .black.withAlphaComponent(0.1)
    public let pageGuideBackgroundColor: UIColor = .black.withAlphaComponent(0.06)

    public let markedTextBackgroundColor: UIColor = .black.withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> UIColor? {
        nil
    }

    public func fontTraits(for rawHighlightName: String) -> FontTraits {
        if let highlightName = HighlightName(rawHighlightName), highlightName == .keyword {
            return .bold
        } else {
            return []
        }
    }
}
