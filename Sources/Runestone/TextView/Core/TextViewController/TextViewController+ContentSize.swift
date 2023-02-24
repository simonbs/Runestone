import Foundation

extension TextViewController {
    func invalidateContentSizeIfNeeded() {
        guard let scrollView, scrollView.contentSize != contentSizeService.contentSize else {
            return
        }
        hasPendingContentSizeUpdate = true
        handleContentSizeUpdateIfNeeded()
        #if os(macOS)
        updateScrollerVisibility()
        #endif
    }

    func handleContentSizeUpdateIfNeeded() {
        guard let scrollView, hasPendingContentSizeUpdate else {
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
        layoutManager.setNeedsLayout()
        textView.setNeedsLayout()
    }

    #if os(macOS)
    func updateScrollerVisibility() {
        guard let scrollView else {
            return
        }
        let hadVerticalScroller = scrollView.hasVerticalScroller
        let hadHorizontalScroller = scrollView.hasHorizontalScroller
        scrollView.hasVerticalScroller = scrollView.contentSize.height > scrollView.frame.height
        scrollView.hasHorizontalScroller = scrollView.contentSize.width > scrollView.frame.width
        scrollView.horizontalScroller?.layer?.zPosition = 1_000
        scrollView.verticalScroller?.layer?.zPosition = 1_000
        layoutManager.verticalScrollerWidth = scrollView.hasVerticalScroller ? scrollView.verticalScroller?.frame.width ?? 0 : 0
        if scrollView.hasVerticalScroller != hadVerticalScroller || scrollView.hasHorizontalScroller != hadHorizontalScroller {
            textView.setNeedsLayout()
        }
    }
    #endif
}
