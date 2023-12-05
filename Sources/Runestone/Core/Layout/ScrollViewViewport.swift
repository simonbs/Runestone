import _RunestoneMultiPlatform
import Foundation

final class ScrollViewViewport: Viewport {
    private(set) var size: CGSize = .zero
    private(set) var origin: CGPoint = .zero

    private var frameObservation: NSKeyValueObservation?
    private var contentOffsetObservation: NSKeyValueObservation?

    init(scrollView: MultiPlatformScrollView) {
        frameObservation = scrollView.observe(\.frame) { [weak self] _, change in
            self?.size = change.newValue?.size ?? .zero
        }
        contentOffsetObservation = scrollView.observe(\.contentOffset) { [weak self] _, change in
            self?.origin = change.newValue ?? .zero
        }
    }
}
