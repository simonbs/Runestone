import UIKit

extension UIFont {
    var totalLineHeight: CGFloat {
        return ascender + abs(descender) + leading
    }
}
