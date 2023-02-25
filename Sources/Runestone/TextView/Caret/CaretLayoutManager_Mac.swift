#if os(macOS)
import Foundation
import LineManager
import MultiPlatform
import StringView

final class CaretLayoutManager {
    var textContainerInset: MultiPlatformEdgeInsets {
        didSet {
            if textContainerInset != oldValue {
                setNeedsLayout()
            }
        }
    }
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

    private let stringView: StringView
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private let caretView = CaretView()
    private var needsLayout = false

    init(
        stringView: StringView,
        lineManager: LineManager,
        textContainerInset: MultiPlatformEdgeInsets,
        lineControllerStorage: LineControllerStorage,
        containerView: MultiPlatformView
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.textContainerInset = textContainerInset
        self.lineControllerStorage = lineControllerStorage
        caretView.layer?.zPosition = 1000
        caretView.isHidden = true
        containerView.addSubview(caretView)
    }

    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {
        guard needsLayout else {
            return
        }
        needsLayout = false
        let caretRectFactory = CaretRectFactory(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            textContainerInset: textContainerInset
        )
        caretView.frame = caretRectFactory.caretRect(at: caretLocation, allowMovingCaretToNextLineFragment: true)
    }
}
#endif
