//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

final class DefaultEditorTheme: EditorTheme {
    private enum CaptureName {
        static let `operator` = "operator"
        static let keyword = "keyword"
        static let variable = "variable"
        static let string = "string"
        static let comment = "comment"
        static let number = "number"
        static let constantBuiltin = "constant.builtin"
        static let punctuationBracket = "punctuation.bracket"
        static let punctuationDelimiter = "punctuation.delimieter"
    }

    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor: UIColor = .secondaryLabel
    let lineNumberFont: UIFont = UIFont(name: "Menlo-Regular", size: 14)!

    var selectedLinesBackgroundColor = UIColor.opaqueSeparator.withAlphaComponent(0.4)
    let selectedLinesLineNumberColor: UIColor = .label
    let selectedLinesGutterBackgroundColor = UIColor.opaqueSeparator.withAlphaComponent(0.4)

    let invisibleCharactersColor: UIColor = .tertiaryLabel

    func textColorForCapture(named captureName: String) -> UIColor? {
        switch captureName {
        case CaptureName.punctuationBracket, CaptureName.punctuationDelimiter:
            return .secondaryLabel
        case CaptureName.operator:
            return .label
        case CaptureName.keyword:
            return .systemOrange
        case CaptureName.variable:
            return .label
        case CaptureName.string:
            return .systemGreen
        case CaptureName.comment:
            return .secondaryLabel
        case CaptureName.number:
            return .systemBlue
        case CaptureName.constantBuiltin:
            return .systemPurple
        default:
            return .label
        }
    }

    func fontForCapture(named captureName: String) -> UIFont? {
        return nil
    }
}
