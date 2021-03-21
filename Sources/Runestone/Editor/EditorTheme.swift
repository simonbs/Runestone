//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

public protocol EditorTheme: AnyObject {
    var font: UIFont { get }
    var textColor: UIColor { get }
    var gutterBackgroundColor: UIColor { get }
    var gutterHairlineColor: UIColor { get }
    var gutterHairlineWidth: CGFloat { get }
    var lineNumberColor: UIColor { get }
    var lineNumberFont: UIFont { get }
    var selectedLineBackgroundColor: UIColor { get }
    var selectedLinesLineNumberColor: UIColor { get }
    var selectedLinesGutterBackgroundColor: UIColor { get }
    var invisibleCharactersColor: UIColor { get }
    var pageGuideHairlineColor: UIColor { get }
    var pageGuideBackgroundColor: UIColor { get }
    func textColorForCaptureSequence(_ captureSequence: String) -> UIColor?
    func fontForCaptureSequence(_ captureSequence: String) -> UIFont?
    func shadowForCaptureSequence(_ captureSequence: String) -> NSShadow?
}

public extension EditorTheme {
    var gutterHairlineWidth: CGFloat {
        return 1 / UIScreen.main.scale
    }

    var pageGuideHairlineWidth: CGFloat {
        return 1 / UIScreen.main.scale
    }

    func fontForCaptureSequence(_ captureSequence: String) -> UIFont? {
        return nil
    }

    func shadowForCaptureSequence(_ captureSequence: String) -> NSShadow? {
        return nil
    }
}
