import Runestone
import UIKit

final class TomorrowTheme: EditorTheme {
    let backgroundColor = UIColor(named: "TomorrowBackground")!
    let userInterfaceStyle: UIUserInterfaceStyle = .light

    let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor = UIColor(named: "TomorrowForeground")!

    let gutterBackgroundColor = UIColor(named: "TomorrowCurrentLine")!
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor = UIColor(named: "TomorrowForeground")!.withAlphaComponent(0.5)
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    let selectedLineBackgroundColor = UIColor(named: "TomorrowCurrentLine")!
    let selectedLinesLineNumberColor = UIColor(named: "TomorrowForeground")!
    let selectedLinesGutterBackgroundColor: UIColor = .clear

    let invisibleCharactersColor = UIColor(named: "TomorrowForeground")!.withAlphaComponent(0.7)

    let pageGuideHairlineColor = UIColor(named: "TomorrowForeground")!
    let pageGuideBackgroundColor = UIColor(named: "TomorrowCurrentLine")!

    let markedTextBackgroundColor = UIColor(named: "TomorrowForeground")!.withAlphaComponent(0.1)
    let markedTextBackgroundCornerRadius: CGFloat = 4

    func textColor(for captureSequence: String) -> UIColor? {
        guard let scope = Scope(captureSequence: captureSequence) else {
            return nil
        }
        switch scope {
        case .comment:
            return UIColor(named: "TomorrowComment")
        case .operator, .punctuation:
            return UIColor(named: "TomorrowForeground")?.withAlphaComponent(0.75)
        case .property:
            return UIColor(named: "TomorrowAqua")
        case .function:
            return UIColor(named: "TomorrowBlue")
        case .string:
            return UIColor(named: "TomorrowGreen")
        case .number:
            return UIColor(named: "TomorrowOrange")
        case .keyword:
            return UIColor(named: "TomorrowPurple")
        case .variableBuiltin:
            return UIColor(named: "TomorrowRed")
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
