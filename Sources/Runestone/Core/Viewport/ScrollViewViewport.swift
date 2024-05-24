import _RunestoneMultiPlatform
import _RunestoneObservation
import Foundation

@RunestoneObservable
final class ScrollViewViewport: Viewport {
    private(set) var size: CGSize = .zero
    private(set) var origin: CGPoint = .zero
    private(set) var safeAreaInsets: MultiPlatformEdgeInsets = .zero

    @RunestoneObservationIgnored
    private var frameObservation: NSKeyValueObservation?
    @RunestoneObservationIgnored
    private var contentOffsetObservation: NSKeyValueObservation?
    @RunestoneObservationIgnored
    private var safeAreaInsetsObservation: NSKeyValueObservation?

    init(scrollView: MultiPlatformScrollView) {
        frameObservation = scrollView.observe(
            \.bounds,
             options: [.initial, .new]
        ) { [weak self] _, change in
            self?.size = change.newValue?.size ?? .zero
        }
        contentOffsetObservation = scrollView.observe(
            \.contentOffset, 
             options: [.initial, .new]
        ) { [weak self] _, change in
            self?.origin = change.newValue ?? .zero
        }
        safeAreaInsetsObservation = scrollView.observe(
            \.safeAreaInsets,
             options: [.initial, .new]
        ) { [weak self] _, change in
            self?.safeAreaInsets = change.newValue ?? .zero
        }
    }
}
