import Runestone
import UIKit

final class PlainTextTheme: EditorTheme {
    let backgroundColor: UIColor = .white
    let userInterfaceStyle: UIUserInterfaceStyle = .light

    let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor: UIColor = .black

    let gutterBackgroundColor: UIColor = .white
    let gutterHairlineColor: UIColor = .white

    let lineNumberColor: UIColor = .black.withAlphaComponent(0.5)
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    let selectedLineBackgroundColor: UIColor = .black.withAlphaComponent(0.07)
    let selectedLinesLineNumberColor: UIColor = .black
    let selectedLinesGutterBackgroundColor: UIColor = .black.withAlphaComponent(0.07)

    let invisibleCharactersColor: UIColor = .black.withAlphaComponent(0.5)

    let pageGuideHairlineColor: UIColor = .black.withAlphaComponent(0.1)
    let pageGuideBackgroundColor: UIColor = .black.withAlphaComponent(0.06)

    let markedTextBackgroundColor: UIColor = .black.withAlphaComponent(0.1)
    let markedTextBackgroundCornerRadius: CGFloat = 4

    func textColor(for captureSequence: String) -> UIColor? {
        return nil
    }

    func fontTraits(for captureSequence: String) -> FontTraits {
        if let scope = Scope(captureSequence: captureSequence), scope == .keyword {
            return .bold
        } else {
            return []
        }
    }
}
