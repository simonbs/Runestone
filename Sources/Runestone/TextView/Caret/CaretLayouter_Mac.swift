#if os(macOS)
import Foundation

final class CaretLayouter {
    var caretLocation = 0 {
        didSet {
            if caretLocation != oldValue {
                caretView.delayBlink()
                setNeedsLayout()
            }
        }
    }
    var showCaret = false {
        didSet {
            if showCaret != oldValue {
                if showCaret {
                    caretView.isHidden = false
                    caretView.isBlinkingEnabled = true
                    caretView.delayBlink()
                } else {
                    caretView.isHidden = true
                    caretView.isBlinkingEnabled = false
                }
            }
        }
    }
    var color: MultiPlatformColor {
        get {
            caretView.color
        }
        set {
            caretView.color = newValue
        }
    }

    private let caretRectProvider: CaretRectProvider
    private let caretView = CaretView()
    private var needsLayout = false

    init(caretRectProvider: CaretRectProvider, containerView: MultiPlatformView) {
        self.caretRectProvider = caretRectProvider
        caretView.layer?.zPosition = 1000
        caretView.isHidden = true
        containerView.addSubview(caretView)
    }

    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {
        if needsLayout {
            needsLayout = false
            caretView.frame = caretRectProvider.caretRect(at: caretLocation, allowMovingCaretToNextLineFragment: true)
        }
    }
}
#endif
