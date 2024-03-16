import Foundation
import UIKit

struct DefaultStringAttributes {
    private let textColor: UIColor
    private let font: UIFont
    private let kern: CGFloat
    private let tabWidth: CGFloat

    init(
        textColor: UIColor,
        font: UIFont,
        kern: CGFloat,
        tabWidth: CGFloat
    ) {
        self.textColor = textColor
        self.font = font
        self.kern = kern
        self.tabWidth = tabWidth
    }

    func apply(to attributedString: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = tabWidth
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
