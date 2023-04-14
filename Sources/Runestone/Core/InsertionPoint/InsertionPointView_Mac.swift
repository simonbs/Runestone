#if os(macOS)
import AppKit
import Combine

final class InsertionPointView: NSView {
    var isBlinkingEnabled = false {
        didSet {
            if isBlinkingEnabled != oldValue {
                blinkTimer?.invalidate()
                if isBlinkingEnabled {
                    blinkTimer = .scheduledTimer(
                        timeInterval: 0.5,
                        target: self,
                        selector: #selector(blink),
                        userInfo: nil,
                        repeats: true
                    )
                }
            }
        }
    }

    private let renderer: InsertionPointRenderer
    private var cancellables: Set<AnyCancellable> = []
    private var blinkTimer: Timer?
    private var isVisible = true {
        didSet {
            if isVisible != oldValue {
                setNeedsDisplay()
            }
        }
    }

    init(selectedRange: AnyPublisher<NSRange, Never>, renderer: InsertionPointRenderer) {
        self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        backgroundColor = .clear
        selectedRange.map { $0.location }.removeDuplicates().sink { [weak self] _ in
            // Must redisplay when the selected range changes to ensure we draw the correct character in the block insertion point.
            self?.setNeedsDisplay()
        }.store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let context = NSGraphicsContext.current?.cgContext {
            context.clear(bounds)
            if isVisible {
                renderer.render(in: bounds, to: context)
            }
        }
    }

    func delayBlink() {
        let wasBlinking = isBlinkingEnabled
        isBlinkingEnabled = false
        isVisible = true
        isBlinkingEnabled = wasBlinking
    }
}

private extension InsertionPointView {
    @objc private func blink() {
        isVisible.toggle()
    }
}
#endif
