import UIKit

final class FoldingGutterButton: UIButton, ReusableView {
    var toggle: (() -> Void)?
    var chevronSize: CGSize = .zero {
        didSet { if chevronSize != oldValue { setNeedsLayout() } }
    }
    private var hasConfiguredActions = false
    private let chevronView = UIImageView(image: UIImage(
        systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
    private var chevronRotation: CGFloat = 0
    private static let rotationAnimationKey = "folding-chevron-rotation"

    var displayedChevronRotation: CGFloat {
        guard let presentation = chevronView.layer.presentation() else {
            return chevronRotation
        }
        return atan2(presentation.transform.m12, presentation.transform.m11)
    }

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupIfNeeded()
    }

    private func setupIfNeeded() {
        guard !hasConfiguredActions else {
            return
        }
        hasConfiguredActions = true
        chevronView.contentMode = .center
        addSubview(chevronView)
        addTarget(self, action: #selector(activate), for: .touchUpInside)
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        chevronView.bounds = CGRect(origin: .zero, size: chevronSize)
        chevronView.center = CGPoint(x: bounds.maxX - chevronSize.width / 2, y: chevronSize.height / 2)
    }

    func configure(row: Int, endRow: Int, isCollapsed: Bool, color: UIColor) {
        setupIfNeeded()
        tintColor = color
        let rotation: CGFloat = isCollapsed ? 0 : .pi / 2
        if rotation != chevronRotation { finishChevronAnimation() }
        chevronRotation = rotation
        chevronView.transform = CGAffineTransform(rotationAngle: chevronRotation)
        accessibilityLabel = "\(isCollapsed ? "Expand" : "Collapse") lines \(row + 1) through \(endRow + 1)"
        accessibilityValue = isCollapsed ? "Collapsed" : "Expanded"
        accessibilityIdentifier = "Runestone.Fold.\(row)"
    }

    func animateChevron(from rotation: CGFloat) {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = rotation
        animation.toValue = chevronRotation
        animation.duration = 0.18
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        chevronView.layer.add(animation, forKey: Self.rotationAnimationKey)
    }

    func finishChevronAnimation() {
        chevronView.layer.removeAnimation(forKey: Self.rotationAnimationKey)
    }

    func prepareForReuse() {
        toggle = nil
        finishChevronAnimation()
    }
    @objc private func activate() { toggle?() }
}

/// Foldable rows consume gutter taps; other rows remain available to scrolling.
final class GutterContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
