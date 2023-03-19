import Foundation

final class ScrollViewBox {
    private(set) weak var scrollView: MultiPlatformScrollView?

    init(_ scrollView: MultiPlatformScrollView? = nil) {
        self.scrollView = scrollView
    }
}
