import Combine
import Foundation

final class ViewportScroller {
    private let _scrollView: CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>
    private let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    private let caret: Caret
    private let estimatedLineHeight: EstimatedLineHeight
    private let lineFragmentLayouter: LineFragmentLayouter
    private let contentSizeService: ContentSizeService
    private var scrollView: MultiPlatformScrollView? {
        _scrollView.value.value
    }

    init(
        scrollView: CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        caret: Caret,
        estimatedLineHeight: EstimatedLineHeight,
        lineFragmentLayouter: LineFragmentLayouter,
        contentSizeService: ContentSizeService
    ) {
        self._scrollView = scrollView
        self.textContainerInset = textContainerInset
        self.caret = caret
        self.estimatedLineHeight = estimatedLineHeight
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
        let lowerBoundCaretRect = caret.frame(at: range.lowerBound, allowMovingCaretToNextLineFragment: true)
        let upperBoundCaretRect = caret.frame(at: range.upperBound, allowMovingCaretToNextLineFragment: true)
        var lowerBoundRect = lowerBoundCaretRect
        var upperBoundRect = upperBoundCaretRect
        lowerBoundRect.origin.y -= (lowerBoundCaretRect.size.height * estimatedLineHeight.value - lowerBoundCaretRect.size.height) / 2
        upperBoundRect.origin.y -= (lowerBoundCaretRect.size.height * estimatedLineHeight.value - lowerBoundCaretRect.size.height) / 2
        lowerBoundRect.size.height = lowerBoundCaretRect.size.height * estimatedLineHeight.value
        upperBoundRect.size.height = lowerBoundCaretRect.size.height * estimatedLineHeight.value
        let rectMinX = min(lowerBoundRect.minX, upperBoundRect.minX)
        let rectMaxX = max(lowerBoundRect.maxX, upperBoundRect.maxX)
        let rectMinY = min(lowerBoundRect.minY, upperBoundRect.minY)
        let rectMaxY = max(lowerBoundRect.maxY, upperBoundRect.maxY)
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
