import Combine
import CoreGraphics
import Foundation

final class ViewportScroller {
    private let _scrollView: CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>
    private let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    private let insertionPointFrameFactory: InsertionPointFrameFactory
    private let lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    private let lineFragmentLayouter: LineFragmentLayouter
    private let contentSizeService: ContentSizeService
    private var scrollView: MultiPlatformScrollView? {
        _scrollView.value.value
    }

    init(
        scrollView: CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        insertionPointFrameFactory: InsertionPointFrameFactory,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>,
        lineFragmentLayouter: LineFragmentLayouter,
        contentSizeService: ContentSizeService
    ) {
        self._scrollView = scrollView
        self.textContainerInset = textContainerInset
        self.insertionPointFrameFactory = insertionPointFrameFactory
        self.lineHeightMultiplier = lineHeightMultiplier
        self.lineFragmentLayouter = lineFragmentLayouter
        self.contentSizeService = contentSizeService
    }

    func scroll(toVisibleRange range: NSRange) {
        lineFragmentLayouter.layoutLines(toLocation: range.upperBound)
        contentSizeService.updateContentSizeIfNeeded()
        justScrollRangeToVisible(range)
    }
}

private extension ViewportScroller {
    private func justScrollRangeToVisible(_ range: NSRange) {
        var lowerRect = insertionPointFrameFactory.frameOfInsertionPoint(at: range.lowerBound)
        var upperRect = insertionPointFrameFactory.frameOfInsertionPoint(at: range.upperBound)
        lowerRect.origin.y -= (lowerRect.size.height * lineHeightMultiplier.value - lowerRect.size.height) / 2
        upperRect.origin.y -= (upperRect.size.height * lineHeightMultiplier.value - upperRect.size.height) / 2
        lowerRect.size.height = lowerRect.size.height * lineHeightMultiplier.value
        upperRect.size.height = upperRect.size.height * lineHeightMultiplier.value
        let rectMinX = min(lowerRect.minX, upperRect.minX)
        let rectMaxX = max(lowerRect.maxX, upperRect.maxX)
        let rectMinY = min(lowerRect.minY, upperRect.minY)
        let rectMaxY = max(lowerRect.maxY, upperRect.maxY)
        let rect = CGRect(x: rectMinX, y: rectMinY, width: rectMaxX - rectMinX, height: rectMaxY - rectMinY)
        scrollView?.contentOffset = contentOffsetForScrollingToVisibleRect(rect)
    }

    /// Computes a content offset to scroll to in order to reveal the specified rectangle.
    ///
    /// The function will return an offset that scrolls the text view a minimum amount while revealing as much as possible of the rectangle. It is not guaranteed that the entire rectangle can be revealed.
    /// - Parameter rect: The rectangle to reveal.
    /// - Returns: The content offset to scroll to.
    private func contentOffsetForScrollingToVisibleRect(_ rect: CGRect) -> CGPoint {
        // Create the viewport: a rectangle containing the content that is visible to the user.
        let contentOffset = scrollView?.contentOffset ?? .zero
//        let adjustedContentInset = scrollView?.adjustedContentInset ?? .zero
//        let textContainerInset = textContainerInset.value
        let viewport = CGRect(origin: contentOffset, size: scrollView?.frame.size ?? .zero)
//        viewport.origin.y += adjustedContentInset.top + textContainerInset.top
//        viewport.origin.x += adjustedContentInset.left + textContainerInset.left
//        viewport.size.width -= adjustedContentInset.left
//        + adjustedContentInset.right
//        + textContainerInset.left
//        + textContainerInset.right
//        viewport.size.height -= adjustedContentInset.top
//        + adjustedContentInset.bottom
//        + textContainerInset.top
//        + textContainerInset.bottom
        // Construct the best possible content offset.
        var newContentOffset = contentOffset
        if rect.minX < viewport.minX {
            newContentOffset.x -= viewport.minX - rect.minX
        } else if rect.maxX > viewport.maxX && rect.width <= viewport.width {
            // The end of the rectangle is not visible and the rect fits within the screen so we'll scroll to reveal the entire rect.
            newContentOffset.x += rect.maxX - viewport.maxX
        } else if rect.maxX > viewport.maxX {
            newContentOffset.x += rect.minX
        }
        if rect.minY < viewport.minY {
            newContentOffset.y -= viewport.minY - rect.minY
        } else if rect.maxY > viewport.maxY && rect.height <= viewport.height {
            // The end of the rectangle is not visible and the rect fits within the screen so we'll scroll to reveal the entire rect.
            newContentOffset.y += rect.maxY - viewport.maxY
        } else if rect.maxY > viewport.maxY {
            newContentOffset.y += rect.minY
        }
        let minimumContentOffset = scrollView?.minimumContentOffset ?? .zero
        let maximumContentOffset = scrollView?.maximumContentOffset ?? .zero
        let cappedXOffset = min(max(newContentOffset.x, minimumContentOffset.x), maximumContentOffset.x)
        let cappedYOffset = min(max(newContentOffset.y, minimumContentOffset.y), maximumContentOffset.y)
        return CGPoint(x: cappedXOffset, y: cappedYOffset)
    }
}
