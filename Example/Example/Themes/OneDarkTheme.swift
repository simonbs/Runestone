import Runestone
import UIKit

final class OneDarkTheme: EditorTheme {
    let backgroundColor = UIColor(named: "OneDarkBackground")!
    let userInterfaceStyle: UIUserInterfaceStyle = .dark

    let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor = UIColor(named: "OneDarkForeground")!

    let gutterBackgroundColor = UIColor(named: "OneDarkCurrentLine")!
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor = UIColor(named: "OneDarkForeground")!.withAlphaComponent(0.5)
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    let selectedLineBackgroundColor = UIColor(named: "OneDarkCurrentLine")!
    let selectedLinesLineNumberColor = UIColor(named: "OneDarkForeground")!
    let selectedLinesGutterBackgroundColor: UIColor = .clear

    let invisibleCharactersColor = UIColor(named: "OneDarkForeground")!.withAlphaComponent(0.7)

    let pageGuideHairlineColor = UIColor(named: "OneDarkForeground")!
    let pageGuideBackgroundColor = UIColor(named: "OneDarkCurrentLine")!

    let markedTextBackgroundColor = UIColor(named: "OneDarkForeground")!.withAlphaComponent(0.1)
    let markedTextBackgroundCornerRadius: CGFloat = 4

    func textColor(for captureSequence: String) -> UIColor? {
        guard let scope = Scope(captureSequence: captureSequence) else {
            return nil
        }
        switch scope {
        case .comment:
            return UIColor(named: "OneDarkComment")
        case .operator, .punctuation:
            return UIColor(named: "OneDarkForeground")?.withAlphaComponent(0.75)
        case .property:
            return UIColor(named: "OneDarkAqua")
        case .function:
            return UIColor(named: "OneDarkBlue")
        case .string:
            return UIColor(named: "OneDarkGreen")
        case .number:
            return UIColor(named: "OneDarkYellow")
        case .keyword:
            return UIColor(named: "OneDarkPurple")
        case .variableBuiltin:
            return UIColor(named: "OneDarkRed")
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
