import UIKit

enum TabWidthMeasurer {
    static func tabWidth(tabLength: Int, font: UIFont) -> CGFloat {
        let str = String(repeating: " ", count: tabLength)
        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesFontLeading, .usesLineFragmentOrigin]
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let bounds = str.boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
        return round(bounds.size.width)
    }
}
