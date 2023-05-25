import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

final class InsertionPointView: MultiPlatformView {
    var isBlinkingEnabled = false {
        didSet {
            if isBlinkingEnabled != oldValue {
                blinkTimer?.invalidate()
                rescheduleBlinkIfNeeded()
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

    init(renderer: InsertionPointRenderer) {
        self.renderer = renderer
        super.init(frame: .zero)
        #if os(macOS)
        wantsLayer = true
        #endif
        backgroundColor = .clear
        renderer.needsRender.sink { [weak self] _ in
            self?.setNeedsDisplay()
        }.store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(macOS)
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let context = NSGraphicsContext.current?.cgContext {
            render(to: context)
        }
    }
    #else
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if let context = UIGraphicsGetCurrentContext() {
            render(to: context)
        }
    }
    #endif

    func delayBlink() {
        let wasBlinking = isBlinkingEnabled
        isBlinkingEnabled = false
        isVisible = true
        isBlinkingEnabled = wasBlinking
    }
}

private extension InsertionPointView {
    private func render(to context: CGContext) {
        context.clear(bounds)
        if isVisible {
            renderer.render(bounds, to: context)
        }
    }

    private func rescheduleBlinkIfNeeded() {
        guard isBlinkingEnabled else {
            return
        }
        blinkTimer = .scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(blink),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func blink() {
        isVisible.toggle()
    }
}
