import Foundation
import UIKit

struct DefaultStringAttributes {
    let textColor: UIColor
    let font: UIFont
    let kern: CGFloat
    let tabWidth: CGFloat

    func apply(to attributedString: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.setAttributes([.foregroundColor: textColor, .font: font], range: range)
        applyLayout(to: attributedString)
    }

    /// Layout settings do not replace the fonts and colors supplied by syntax captures.
    func applyLayout(to attributedString: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = (0 ..< 20).map { index in
            NSTextTab(textAlignment: .natural, location: CGFloat(index) * tabWidth)
        }
        paragraphStyle.defaultTabInterval = tabWidth
        let range = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [
            .kern: kern as NSNumber,
            .paragraphStyle: paragraphStyle
        ]
        attributedString.beginEditing()
        attributedString.addAttributes(attributes, range: range)
        attributedString.endEditing()
    }
}
