//
//  TomorrowTheme.swift
//  Example
//
//  Created by Simon on 19/01/2022.
//

import Runestone
import UIKit

final class TomorrowTheme: Theme {
    let font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    let textColor = UIColor(named: "Foreground")!

    let gutterBackgroundColor = UIColor(named: "CurrentLine")!
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor = UIColor(named: "Foreground")!.withAlphaComponent(0.5)
    let lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    let selectedLineBackgroundColor = UIColor(named: "CurrentLine")!
    let selectedLinesLineNumberColor = UIColor(named: "Foreground")!
    let selectedLinesGutterBackgroundColor: UIColor = .clear

    let invisibleCharactersColor = UIColor(named: "Foreground")!.withAlphaComponent(0.7)

    let pageGuideHairlineColor = UIColor(named: "Foreground")!
    let pageGuideBackgroundColor = UIColor(named: "CurrentLine")!

    let markedTextBackgroundColor = UIColor(named: "Foreground")!.withAlphaComponent(0.1)
    let markedTextBackgroundCornerRadius: CGFloat = 4

    func textColor(for captureSequence: String) -> UIColor? {
        guard let scope = Scope(captureSequence: captureSequence) else {
            return nil
        }
        switch scope {
        case .comment:
            return UIColor(named: "Comment")
        case .operator, .punctuation:
            return UIColor(named: "Foreground")?.withAlphaComponent(0.75)
        case .property:
            return UIColor(named: "Aqua")
        case .function:
            return UIColor(named: "Blue")
        case .string:
            return UIColor(named: "Green")
        case .number:
            return UIColor(named: "Orange")
        case .keyword:
            return UIColor(named: "Purple")
        case .variableBuiltin:
            return UIColor(named: "Red")
        }
    }

    func fontTraits(for captureSequence: String) -> FontTraits {
        if let scope = Scope(captureSequence: captureSequence), scope == .keyword {
            return .bold
        } else {
            return []
        }
    }

    func font(for captureSequence: String) -> UIFont? {
        return nil
    }

    func shadow(for captureSequence: String) -> NSShadow? {
        return nil
    }
}
