import UIKit

extension UIFont {
    var totalLineHeight: CGFloat {
        ascender + abs(descender) + leading
    }
}
