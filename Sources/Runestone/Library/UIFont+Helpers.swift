//
//  UIFont+Helpers.swift
//  
//
//  Created by Simon on 06/01/2022.
//

import UIKit

extension UIFont {
    var totalLineHeight: CGFloat {
        return ascender + abs(descender) + leading
    }
}

