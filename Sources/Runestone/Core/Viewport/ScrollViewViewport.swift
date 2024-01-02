import _RunestoneMultiPlatform
import _RunestoneObservation
import Foundation

@RunestoneObservable
final class ScrollViewViewport: Viewport {
    private(set) var size: CGSize = .zero
    private(set) var origin: CGPoint = .zero

    @RunestoneObservationIgnored
    private var frameObservation: NSKeyValueObservation?
    @RunestoneObservationIgnored
    private var contentOffsetObservation: NSKeyValueObservation?

    init(scrollView: MultiPlatformScrollView) {
        frameObservation = scrollView.observe(
            \.bounds,
             options: [.initial, .new]
        ) { [weak self] scrollView, change in
            self?.size = change.newValue?.size ?? .zero
        }
        contentOffsetObservation = scrollView.observe(
            \.contentOffset, 
             options: [.initial, .new]
        ) { [weak self] scrollView, change in
            self?.origin = change.newValue ?? .zero
        }
    }
}
