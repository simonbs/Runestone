import Runestone
import UIKit

class TomorrowTheme: Theme {
    let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor: UIColor = .tomorrow.foreground

    let gutterBackgroundColor: UIColor = .tomorrow.background
    let gutterHairlineColor: UIColor = .tomorrow.background

    let lineNumberColor: UIColor = .tomorrow.comment
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    let selectedLineBackgroundColor: UIColor = .tomorrow.currentLine
    let selectedLinesLineNumberColor: UIColor = .tomorrow.foreground
    let selectedLinesGutterBackgroundColor: UIColor = .tomorrow.background

    let invisibleCharactersColor: UIColor = .tomorrow.comment

    let pageGuideHairlineColor: UIColor = .tomorrow.foreground.withAlphaComponent(0.1)
    let pageGuideBackgroundColor: UIColor = .tomorrow.foreground.withAlphaComponent(0.2)

    let markedTextBackgroundColor: UIColor = .tomorrow.foreground.withAlphaComponent(0.2)

    func textColor(for highlightName: String) -> UIColor? {
        guard let highlightName = HighlightName(highlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return .tomorrow.comment
        case .constructor:
            return .tomorrow.yellow
        case .function:
            return .tomorrow.blue
        case .keyword, .type:
            return .tomorrow.purple
        case .number, .constantBuiltin, .constantCharacter:
            return .tomorrow.orange
        case .property:
            return .tomorrow.aqua
        case .string:
            return .tomorrow.green
        case .variableBuiltin:
            return .tomorrow.red
        case .operator, .punctuation:
            return .tomorrow.foreground.withAlphaComponent(0.75)
        case .variable:
            return nil
        }
    }
}
