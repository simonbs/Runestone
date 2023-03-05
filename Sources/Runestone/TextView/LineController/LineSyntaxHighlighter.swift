import Combine
import CoreGraphics
import Foundation

extension NSAttributedString.Key {
    static let isBold = NSAttributedString.Key("runestone_isBold")
    static let isItalic = NSAttributedString.Key("runestone_isItalic")
}

struct LineSyntaxHiglighterSetAttributesResult {
    let isSizingInvalid: Bool
}

final class LineSyntaxHighlighterInput {
    let attributedString: NSMutableAttributedString
    let byteRange: ByteRange

    init(attributedString: NSMutableAttributedString, byteRange: ByteRange) {
        self.attributedString = attributedString
        self.byteRange = byteRange
    }
}

protocol LineSyntaxHighlighter: AnyObject {
    typealias AsyncCallback = (Result<Void, Error>) -> Void
    var theme: CurrentValueSubject<Theme, Never> { get }
    var kern: CurrentValueSubject<CGFloat, Never> { get }
    var canHighlight: Bool { get }
    func setDefaultAttributes(on attributedString: NSMutableAttributedString)
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput)
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback)
    func cancel()
}

extension LineSyntaxHighlighter {
    func setDefaultAttributes(on attributedString: NSMutableAttributedString) {
        let entireRange = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.value.textColor,
            .font: theme.value.font,
            .kern: kern.value as NSNumber
        ]
        attributedString.beginEditing()
        attributedString.setAttributes(attributes, range: entireRange)
        attributedString.endEditing()
    }
}
