import Foundation

extension TextViewController {
    func invalidateContentSizeIfNeeded() {
        if scrollView.contentSize != contentSizeService.contentSize {
            hasPendingContentSizeUpdate = true
            handleContentSizeUpdateIfNeeded()
            #if os(macOS)
            updateScrollerVisibility()
            #endif
        }
    }

    func handleContentSizeUpdateIfNeeded() {
        guard hasPendingContentSizeUpdate else {
            return
        }
        // We don't want to update the content size when the scroll view is "bouncing" near the gutter,
        // or at the end of a line since it causes flickering when updating the content size while scrolling.
        // However, we do allow updating the content size if the text view is scrolled far enough on
        // the y-axis as that means it will soon run out of text to display.
        let gutterBounceOffset = scrollView.contentInset.left * -1
        let lineEndBounceOffset = scrollView.contentSize.width - scrollView.frame.size.width + scrollView.contentInset.right
        let isBouncingAtGutter = scrollView.contentOffset.x < gutterBounceOffset
        let isBouncingAtLineEnd = scrollView.contentOffset.x > lineEndBounceOffset
        let isBouncingHorizontally = isBouncingAtGutter || isBouncingAtLineEnd
        let isCriticalUpdate = scrollView.contentOffset.y > scrollView.contentSize.height - scrollView.frame.height * 1.5
        let isScrolling = scrollView.isDragging || scrollView.isDecelerating
        guard !isBouncingHorizontally || isCriticalUpdate || !isScrolling else {
            return
        }
        hasPendingContentSizeUpdate = false
        let oldContentOffset = scrollView.contentOffset
        scrollView.contentSize = contentSizeService.contentSize
        scrollView.contentOffset = oldContentOffset
        textView.setNeedsLayout()
    }

    #if os(macOS)
    func updateScrollerVisibility() {
        let hadVerticalScroller = scrollView.hasVerticalScroller
        let hadHorizontalScroller = scrollView.hasHorizontalScroller
        scrollView.hasVerticalScroller = scrollView.contentSize.height > scrollView.frame.height
        scrollView.hasHorizontalScroller = scrollView.contentSize.width > scrollView.frame.width
        scrollView.horizontalScroller?.layer?.zPosition = 1_000
        scrollView.verticalScroller?.layer?.zPosition = 1_000
        layoutManager.verticalScrollerWidth = scrollView.verticalScrollerWidth
        contentSizeService.verticalScrollerWidth = scrollView.verticalScrollerWidth
        if scrollView.hasVerticalScroller != hadVerticalScroller || scrollView.hasHorizontalScroller != hadHorizontalScroller {
            textView.setNeedsLayout()
        }
    }
    #endif
}

#if os(macOS)
private extension MultiPlatformScrollView {
    var verticalScrollerWidth: CGFloat {
        hasVerticalScroller ? verticalScroller?.frame.width ?? 0 : 0
    }
}
#endif
