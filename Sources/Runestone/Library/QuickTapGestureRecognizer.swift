import UIKit

final class QuickTapGestureRecognizer: UITapGestureRecognizer {
    var maximumPressDuration: TimeInterval = 0.3

    private var cancelTimer: Timer?

    override var state: UIGestureRecognizer.State {
        didSet {
            if state != oldValue {
                invalidateTimer()
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        invalidateTimer()
        scheduleTimer()
    }

    @objc private func cancel() {
        invalidateTimer()
        state = .cancelled
    }

    private func scheduleTimer() {
        cancelTimer = .scheduledTimer(timeInterval: maximumPressDuration, target: self, selector: #selector(cancel), userInfo: nil, repeats: false)
    }

    private func invalidateTimer() {
        cancelTimer?.invalidate()
        cancelTimer = nil
    }
}
