import UIKit

final class GutterBackgroundView: UIView {
    var hairlineWidth: CGFloat = 1 {
        didSet {
            if hairlineWidth != oldValue {
                setNeedsLayout()
            }
        }
    }
    var hairlineColor: UIColor? {
        get {
            hairlineView.backgroundColor
        }
        set {
            hairlineView.backgroundColor = newValue
        }
    }

    private let hairlineView = UIView()

    override init(frame: CGRect = .zero) {
        super.init(frame: .zero)
        addSubview(hairlineView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hairlineView.frame = CGRect(x: bounds.width - hairlineWidth, y: 0, width: hairlineWidth, height: bounds.height)
    }
}
