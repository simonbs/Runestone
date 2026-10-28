import UIKit

final class FoldingGutterButton: UIButton, ReusableView {
    var toggle: (() -> Void)?
    private var hasConfiguredActions = false

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupIfNeeded()
    }

    private func setupIfNeeded() {
        guard !hasConfiguredActions else {
            return
        }
        hasConfiguredActions = true
        setImage(UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)), for: .normal)
        addTarget(self, action: #selector(activate), for: .touchUpInside)
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(row: Int, endRow: Int, isCollapsed: Bool, color: UIColor) {
        setupIfNeeded()
        tintColor = color
        imageView?.transform = isCollapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
        accessibilityLabel = "\(isCollapsed ? "Expand" : "Collapse") lines \(row + 1) through \(endRow + 1)"
        accessibilityValue = isCollapsed ? "Collapsed" : "Expanded"
        accessibilityIdentifier = "Runestone.Fold.\(row)"
    }

    func prepareForReuse() { toggle = nil }
    @objc private func activate() { toggle?() }
}

/// Only disclosure controls consume touches; the remainder of the gutter stays available to scrolling.
final class GutterContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
