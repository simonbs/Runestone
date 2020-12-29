//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

final class DefaultEditorTheme: EditorTheme {
    private enum CaptureName: String {
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

    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor: UIColor = .secondaryLabel
    let lineNumberFont = UIFont(name: "Menlo-Regular", size: 14)!

    var selectedLineBackgroundColor: UIColor = .secondarySystemBackground
    let selectedLinesLineNumberColor: UIColor = .label
    let selectedLinesGutterBackgroundColor = UIColor.opaqueSeparator.withAlphaComponent(0.4)

    let invisibleCharactersColor: UIColor = .tertiaryLabel

    func textColorForCapture(named rawCaptureName: String) -> UIColor? {
        guard let captureName = CaptureName(rawValue: rawCaptureName) else {
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

    func fontForCapture(named captureName: String) -> UIFont? {
        guard let captureName = CaptureName(rawValue: captureName) else {
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
