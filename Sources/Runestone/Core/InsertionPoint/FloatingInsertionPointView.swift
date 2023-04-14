#if os(iOS)
import UIKit

final class FloatingInsertionPointView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = floor(bounds.width / 2)
    }
}
#endif
