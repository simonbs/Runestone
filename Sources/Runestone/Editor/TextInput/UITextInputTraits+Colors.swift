//
//  UITextInputTraits+Colors.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import UIKit

private var caretColorKey: Void?

extension UITextInput {
    var caretColor: UIColor? {
        get {
            return objc_getAssociatedObject(self, &caretColorKey) as? UIColor
        }
        set {
            objc_setAssociatedObject(self, &caretColorKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
