import UIKit

final class DefaultTheme: Theme {
    fileprivate enum CaptureName: String {
        case `operator` = "operator"
        case keyword = "keyword"
        case variable = "variable"
        case string = "string"
        case comment = "comment"
        case number = "number"
        case constant = "constant"
        case constantBuiltin = "constant.builtin"
        case property = "property"
        case punctuationBracket = "punctuation.bracket"
        case punctuationDelimiter = "punctuation.delimiter"
    }

    let textColor: UIColor = .label
    let font = UIFont(name: "Menlo-Regular", size: 14)!

    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor: UIColor = .secondaryLabel
    let lineNumberFont = UIFont(name: "Menlo-Regular", size: 14)!

    let selectedLineBackgroundColor: UIColor = .secondarySystemBackground
    let selectedLinesLineNumberColor: UIColor = .label
    let selectedLinesGutterBackgroundColor = UIColor.opaqueSeparator.withAlphaComponent(0.4)

    let invisibleCharactersColor: UIColor = .tertiaryLabel

    let pageGuideBackgroundColor: UIColor = .secondarySystemBackground
    let pageGuideHairlineColor: UIColor = .opaqueSeparator

    let markedTextBackgroundColor: UIColor = .systemFill
    let markedTextBackgroundBorderColor: UIColor = .clear

    func textColor(for captureSequence: String) -> UIColor? {
        guard let captureName = CaptureName(sequence: captureSequence) else {
            return nil
        }
        switch captureName {
        case .punctuationBracket, .punctuationDelimiter, .operator:
            return .secondaryLabel
        case .comment:
            return .secondaryLabel
        case .variable:
            return .label
        case .keyword:
            return .systemPurple
        case .string:
            return .systemGreen
        case .number:
            return .systemOrange
        case .property:
            return .systemBlue
        case .constant:
            return .systemOrange
        case .constantBuiltin:
            return .systemRed
        }
    }

    func font(for captureSequence: String) -> UIFont? {
        guard let captureName = CaptureName(sequence: captureSequence) else {
            return nil
        }
        switch captureName {
        case .keyword:
            return UIFont(name: "Menlo-Bold", size: 14)!
        default:
            return nil
        }
    }
}

private extension DefaultTheme.CaptureName {
    init?(sequence: String) {
        // From the Tree-sitter documentation:
        //
        //   For a given highlight produced, styling will be determined based on the longest matching theme key.
        //   For example, the highlight function.builtin.static would match the key function.builtin rather than function.
        //
        //  https://tree-sitter.github.io/tree-sitter/syntax-highlighting
        var comps = sequence.split(separator: ".")
        var result: Self?
        while result == nil && !comps.isEmpty {
            let rawValue = comps.joined(separator: ".")
            result = Self(rawValue: rawValue)
            comps.removeLast()
        }
        if let result = result {
            self = result
        } else {
            return nil
        }
    }
}
