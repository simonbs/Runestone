//
//  File.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

public struct FontTraits: OptionSet {
    public static let bold = FontTraits(rawValue: 1 << 0)
    public static let italic = FontTraits(rawValue: 1 << 1)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

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
    func fontTraitsForCaptureSequence(_ captureSequence: String) -> FontTraits
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

    func fontTraitsForCaptureSequence(_ captureSequence: String) -> FontTraits {
        return []
    }

    func shadowForCaptureSequence(_ captureSequence: String) -> NSShadow? {
        return nil
    }
}
