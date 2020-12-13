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
    var lineNumberColor: UIColor = .secondaryLabel
    let lineNumberFont: UIFont = .systemFont(ofSize: 14)
}
