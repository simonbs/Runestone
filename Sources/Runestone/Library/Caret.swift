import UIKit

enum Caret {
    static let width: CGFloat = 2

    static func defaultHeight(for font: UIFont?) -> CGFloat {
        font?.lineHeight ?? 15
    }
}
