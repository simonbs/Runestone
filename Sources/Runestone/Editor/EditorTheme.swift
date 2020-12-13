//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

public protocol EditorTheme {
    var gutterBackgroundColor: UIColor { get }
    var gutterHairlineColor: UIColor { get }
    var gutterHairlineWidth: CGFloat { get }
    var lineNumberColor: UIColor { get }
    var lineNumberFont: UIFont { get }
    var lineNumberColorOnSelectedLine: UIColor { get }
    var gutterBackgroundColorOnSelectedLine: UIColor { get }
}

extension EditorTheme {
    var gutterHairlineWidth: CGFloat {
        return 1 / UIScreen.main.scale
    }
}
