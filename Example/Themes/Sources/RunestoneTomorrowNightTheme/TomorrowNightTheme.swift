import Runestone
import RunestoneThemeCommon
import UIKit

public final class TomorrowNightTheme: EditorTheme {
    public let backgroundColor = UIColor(namedInModule: "TomorrowNightBackground")
    public let userInterfaceStyle: UIUserInterfaceStyle = .dark

    public let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = UIColor(namedInModule: "TomorrowNightForeground")

    public let gutterBackgroundColor = UIColor(namedInModule: "TomorrowNightCurrentLine")
    public let gutterHairlineColor = UIColor(namedInModule: "TomorrowNightComment")

    public let lineNumberColor = UIColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.5)
    public let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor = UIColor(namedInModule: "TomorrowNightCurrentLine")
    public let selectedLinesLineNumberColor = UIColor(namedInModule: "TomorrowNightForeground")
    public let selectedLinesGutterBackgroundColor: UIColor = .clear

    public let invisibleCharactersColor = UIColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.7)

    public let pageGuideHairlineColor = UIColor(namedInModule: "TomorrowNightForeground")
    public let pageGuideBackgroundColor = UIColor(namedInModule: "TomorrowNightCurrentLine")

    public let markedTextBackgroundColor = UIColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> UIColor? {
        guard let highlightName = HighlightName(rawHighlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return UIColor(namedInModule: "TomorrowNightComment")
        case .operator, .punctuation:
            return UIColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.75)
        case .property:
            return UIColor(namedInModule: "TomorrowNightAqua")
        case .function:
            return UIColor(namedInModule: "TomorrowNightBlue")
        case .string:
            return UIColor(namedInModule: "TomorrowNightGreen")
        case .number:
            return UIColor(namedInModule: "TomorrowNightOrange")
        case .keyword:
            return UIColor(namedInModule: "TomorrowNightPurple")
        case .variableBuiltin:
            return UIColor(namedInModule: "TomorrowNightRed")
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
