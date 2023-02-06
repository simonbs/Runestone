import Foundation

final class GutterBackgroundView: MultiPlatformView {
    var hairlineWidth: CGFloat = 1 {
        didSet {
            if hairlineWidth != oldValue {
                setNeedsLayout()
            }
        }
    }
    var hairlineColor: MultiPlatformColor? {
        get {
            hairlineView.backgroundColor
        }
        set {
            hairlineView.backgroundColor = newValue
        }
    }

    private let hairlineView = MultiPlatformView()

    override init(frame: CGRect = .zero) {
        super.init(frame: .zero)
        #if os(macOS)
        hairlineView.wantsLayer = true
        #endif
        addSubview(hairlineView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(iOS)
    override func layoutSubviews() {
        super.layoutSubviews()
        _layoutSubviews()
    }
    #else
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        _layoutSubviews()
    }
    #endif
}

private extension GutterBackgroundView {
    private func _layoutSubviews() {
        hairlineView.frame = CGRect(x: bounds.width - hairlineWidth, y: 0, width: hairlineWidth, height: bounds.height)
    }
}
