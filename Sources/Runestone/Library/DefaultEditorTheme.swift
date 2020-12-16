//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

final class DefaultEditorTheme: EditorTheme {
    let gutterBackgroundColor: UIColor = .secondarySystemBackground
    let gutterHairlineColor: UIColor = .opaqueSeparator

    let lineNumberColor: UIColor = .secondaryLabel
    let lineNumberFont: UIFont = UIFont(name: "Menlo-Regular", size: 14)!

    var selectedLinesBackgroundColor = UIColor.opaqueSeparator.withAlphaComponent(0.4)
    let selectedLinesLineNumberColor: UIColor = .label
    let selectedLinesGutterBackgroundColor = UIColor.opaqueSeparator.withAlphaComponent(0.4)
}
