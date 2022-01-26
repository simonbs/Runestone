//
//  Theme.swift
//  
//
//  Created by Simon Støvring on 13/12/2020.
//

import UIKit

/// Fonts and colors to be used by a `TextView`.
public protocol Theme: AnyObject {
    /// Default font of text in the text view.
    var font: UIFont { get }
    /// Default color of text in the text view.
    var textColor: UIColor { get }
    /// Background color of the gutter containing line numbers.
    var gutterBackgroundColor: UIColor { get }
    /// Color of the hairline next to the gutter containing line numbers.
    var gutterHairlineColor: UIColor { get }
    /// Width of the hairline next to the gutter containing line numbers.
    var gutterHairlineWidth: CGFloat { get }
    /// Color of the line numbers in the gutter.
    var lineNumberColor: UIColor { get }
    /// Font of the line nubmers in the gutter.
    var lineNumberFont: UIFont { get }
    /// Background color of the selected line.
    var selectedLineBackgroundColor: UIColor { get }
    /// Color of the line number of the selected line.
    var selectedLinesLineNumberColor: UIColor { get }
    /// Background color of the gutter for selected lines.
    var selectedLinesGutterBackgroundColor: UIColor { get }
    /// Color of invisible characters, i.e. dots, spaces and line breaks.
    var invisibleCharactersColor: UIColor { get }
    /// Color of the hairline next to the page guide.
    var pageGuideHairlineColor: UIColor { get }
    /// Background color of the page guide.
    var pageGuideBackgroundColor: UIColor { get }
    /// Background color of marked text. Text will be marked when writing certain languages, for example Chinese and Japanese.
    var markedTextBackgroundColor: UIColor { get }
    /// Corner radius of the background of marked text. Text will be marked when writing certain languages, for example Chinese and Japanese.
    /// A value of zero or less means that the background will not have rounded corners. Defaults to 0.
    var markedTextBackgroundCornerRadius: CGFloat { get }
    /// Color of text matching the capture sequence.
    ///
    /// See <doc:UnderstandingCaptureSequences> for more information on capture sequences.
    func textColor(for captureSequence: String) -> UIColor?
    /// Font of text matching the capture sequence.
    ///
    /// See <doc:UnderstandingCaptureSequences> for more information on capture sequences.
    func font(for captureSequence: String) -> UIFont?
    /// Traits of text matching the capture sequence.
    ///
    /// See <doc:UnderstandingCaptureSequences> for more information on capture sequences.
    func fontTraits(for captureSequence: String) -> FontTraits
    /// Shadow of text matching the capture sequence.
    ///
    /// See <doc:UnderstandingCaptureSequences> for more information on capture sequences.
    func shadow(for captureSequence: String) -> NSShadow?
}

public extension Theme {
    var gutterHairlineWidth: CGFloat {
        return 1 / UIScreen.main.scale
    }

    var pageGuideHairlineWidth: CGFloat {
        return 1 / UIScreen.main.scale
    }

    var markedTextBackgroundCornerRadius: CGFloat {
        return 0
    }

    func font(for captureSequence: String) -> UIFont? {
        return nil
    }

    func fontTraits(for captureSequence: String) -> FontTraits {
        return []
    }

    func shadow(for captureSequence: String) -> NSShadow? {
        return nil
    }
}
