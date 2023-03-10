import Combine
import Foundation

final class DefaultStringAttributes {
    private let font: CurrentValueSubject<MultiPlatformFont, Never>
    private let textColor: CurrentValueSubject<MultiPlatformColor, Never>
    private let kern: CurrentValueSubject<CGFloat, Never>

    init(
        font: CurrentValueSubject<MultiPlatformFont, Never>,
        textColor: CurrentValueSubject<MultiPlatformColor, Never>,
        kern: CurrentValueSubject<CGFloat, Never>
    ) {
        self.font = font
        self.textColor = textColor
        self.kern = kern
    }

    func apply(to attributedString: NSMutableAttributedString) {
        let entireRange = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font.value,
            .foregroundColor: textColor.value,
            .kern: kern.value as NSNumber
        ]
        attributedString.beginEditing()
        attributedString.setAttributes(attributes, range: entireRange)
        attributedString.endEditing()
    }
}
