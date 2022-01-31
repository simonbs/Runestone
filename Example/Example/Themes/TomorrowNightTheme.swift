import Runestone
import UIKit

final class TomorrowNightTheme: EditorTheme {
    let backgroundColor = UIColor(named: "TomorrowNightBackground")!
    let userInterfaceStyle: UIUserInterfaceStyle = .dark

    let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor = UIColor(named: "TomorrowNightForeground")!

    let gutterBackgroundColor = UIColor(named: "TomorrowNightCurrentLine")!
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor = UIColor(named: "TomorrowNightForeground")!.withAlphaComponent(0.5)
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    let selectedLineBackgroundColor = UIColor(named: "TomorrowNightCurrentLine")!
    let selectedLinesLineNumberColor = UIColor(named: "TomorrowNightForeground")!
    let selectedLinesGutterBackgroundColor: UIColor = .clear

    let invisibleCharactersColor = UIColor(named: "TomorrowNightForeground")!.withAlphaComponent(0.7)

    let pageGuideHairlineColor = UIColor(named: "TomorrowNightForeground")!
    let pageGuideBackgroundColor = UIColor(named: "TomorrowNightCurrentLine")!

    let markedTextBackgroundColor = UIColor(named: "TomorrowNightForeground")!.withAlphaComponent(0.1)
    let markedTextBackgroundCornerRadius: CGFloat = 4

    func textColor(for captureSequence: String) -> UIColor? {
        guard let scope = Scope(captureSequence: captureSequence) else {
            return nil
        }
        switch scope {
        case .comment:
            return UIColor(named: "TomorrowNightComment")
        case .operator, .punctuation:
            return UIColor(named: "TomorrowNightForeground")?.withAlphaComponent(0.75)
        case .property:
            return UIColor(named: "TomorrowNightAqua")
        case .function:
            return UIColor(named: "TomorrowNightBlue")
        case .string:
            return UIColor(named: "TomorrowNightGreen")
        case .number:
            return UIColor(named: "TomorrowNightOrange")
        case .keyword:
            return UIColor(named: "TomorrowNightPurple")
        case .variableBuiltin:
            return UIColor(named: "TomorrowNightRed")
        }
    }

    func fontTraits(for captureSequence: String) -> FontTraits {
        if let scope = Scope(captureSequence: captureSequence), scope == .keyword {
            return .bold
        } else {
            return []
        }
    }
}
