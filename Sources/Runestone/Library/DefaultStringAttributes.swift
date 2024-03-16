import Foundation
import UIKit

struct DefaultStringAttributes {
    private let textColor: UIColor
    private let font: UIFont
    private let kern: CGFloat
    private let tabWidth: CGFloat
    private let lineHeightMultiplier: CGFloat

    init(
        textColor: UIColor,
        font: UIFont,
        kern: CGFloat,
        tabWidth: CGFloat,
        lineHeightMultiplier: CGFloat = 1
    ) {
        self.textColor = textColor
        self.font = font
        self.kern = kern
        self.tabWidth = tabWidth
        self.lineHeightMultiplier = lineHeightMultiplier
    }

    func apply(to attributedString: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = tabWidth
        paragraphStyle.lineHeightMultiple = lineHeightMultiplier
        let range = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font,
            .kern: kern as NSNumber,
            .paragraphStyle: paragraphStyle
        ]
        attributedString.beginEditing()
        attributedString.setAttributes(attributes, range: range)
        attributedString.endEditing()
    }
}
