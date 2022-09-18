import UIKit

final class FloatingCaretView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = floor(bounds.width / 2)
    }
}
