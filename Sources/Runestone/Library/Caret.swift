//
//  Caret.swift
//  
//
//  Created by Simon Støvring on 13/01/2021.
//

import UIKit

enum Caret {
    static let width: CGFloat = 3

    static func defaultHeight(for font: UIFont?) -> CGFloat {
        return font?.lineHeight ?? 15
    }
}
