#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

final class PageGuideView: MultiPlatformView {
    var hairlineWidth: CGFloat {
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

    override init(frame: CGRect) {
        #if os(iOS)
        hairlineWidth = 1 / UIScreen.main.scale
        #else
        hairlineWidth = 1 / NSScreen.main!.backingScaleFactor
        #endif
        super.init(frame: frame)
        #if os(iOS)
        isUserInteractionEnabled = false
        hairlineView.isUserInteractionEnabled = false
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

private extension PageGuideView {
    private func _layoutSubviews() {
        hairlineView.frame = CGRect(x: 0, y: 0, width: hairlineWidth, height: bounds.height)
    }
}
