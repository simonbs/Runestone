import UIKit

final class HighlightView: UIView, ReusableView {
    func update(with highlightRect: HighlightRect) {
        frame = highlightRect.rect
        backgroundColor = highlightRect.color
        layer.cornerCurve = .continuous
        if highlightRect.cornerRadius > 0 && highlightRect.containsStart && highlightRect.containsEnd {
            layer.masksToBounds = true
            layer.cornerRadius = highlightRect.cornerRadius
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if highlightRect.cornerRadius > 0 && highlightRect.containsStart {
            layer.masksToBounds = true
            layer.cornerRadius = highlightRect.cornerRadius
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        } else if highlightRect.cornerRadius > 0 && highlightRect.containsEnd {
            layer.masksToBounds = true
            layer.cornerRadius = highlightRect.cornerRadius
            layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        } else {
            layer.masksToBounds = false
            layer.cornerRadius = 0
            layer.maskedCorners = []
        }
    }
}
