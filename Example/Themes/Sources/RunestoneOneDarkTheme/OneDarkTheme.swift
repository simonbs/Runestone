import Runestone
import RunestoneThemeCommon
import UIKit

public final class OneDarkTheme: EditorTheme {
    public let backgroundColor = UIColor(namedInModule: "OneDarkBackground")
    public let userInterfaceStyle: UIUserInterfaceStyle = .dark

    public let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = UIColor(namedInModule: "OneDarkForeground")

    public let gutterBackgroundColor = UIColor(namedInModule: "OneDarkCurrentLine")
    public let gutterHairlineColor: UIColor = .opaqueSeparator

    public let lineNumberColor = UIColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.5)
    public let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor = UIColor(namedInModule: "OneDarkCurrentLine")
    public let selectedLinesLineNumberColor = UIColor(namedInModule: "OneDarkForeground")
    public let selectedLinesGutterBackgroundColor: UIColor = .clear

    public let invisibleCharactersColor = UIColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.7)

    public let pageGuideHairlineColor = UIColor(namedInModule: "OneDarkForeground")
    public let pageGuideBackgroundColor = UIColor(namedInModule: "OneDarkCurrentLine")

    public let markedTextBackgroundColor = UIColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> UIColor? {
        guard let highlightName = HighlightName(rawHighlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return UIColor(namedInModule: "OneDarkComment")
        case .operator, .punctuation:
            return UIColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.75)
        case .property:
            return UIColor(namedInModule: "OneDarkAqua")
        case .function:
            return UIColor(namedInModule: "OneDarkBlue")
        case .string:
            return UIColor(namedInModule: "OneDarkGreen")
        case .number:
            return UIColor(namedInModule: "OneDarkYellow")
        case .keyword:
            return UIColor(namedInModule: "OneDarkPurple")
        case .variableBuiltin:
            return UIColor(namedInModule: "OneDarkRed")
        }
    }

    public func fontTraits(for rawHighlightName: String) -> FontTraits {
        if let highlightName = HighlightName(rawHighlightName), highlightName == .keyword {
            return .bold
        } else {
            return []
        }
    }
}

private extension UIColor {
    convenience init(namedInModule name: String) {
        self.init(named: name, in: .module, compatibleWith: nil)!
    }
}
