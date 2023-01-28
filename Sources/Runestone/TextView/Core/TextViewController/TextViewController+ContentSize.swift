import Foundation

extension TextViewController {
    var contentSize: CGSize {
        let horizontalOverscrollLength = max(textView.frame.width * horizontalOverscrollFactor, 0)
        let verticalOverscrollLength = max(textView.frame.height * verticalOverscrollFactor, 0)
        let baseContentSize = contentSizeService.contentSize
        let width = isLineWrappingEnabled ? baseContentSize.width : baseContentSize.width + horizontalOverscrollLength
        let height = baseContentSize.height + verticalOverscrollLength
        return CGSize(width: width, height: height)
    }

    func invalidateContentSizeIfNeeded() {
        if textView.contentSize != contentSize {
            hasPendingContentSizeUpdate = true
            handleContentSizeUpdateIfNeeded()
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
        let isBouncingAtGutter = textView.contentOffset.x < -textView.contentInset.left
        let isBouncingAtLineEnd = textView.contentOffset.x > textView.contentSize.width - textView.frame.size.width + textView.contentInset.right
        let isBouncingHorizontally = isBouncingAtGutter || isBouncingAtLineEnd
        let isCriticalUpdate = textView.contentOffset.y > textView.contentSize.height - textView.frame.height * 1.5
        let isScrolling = textView.isDragging || textView.isDecelerating
        guard !isBouncingHorizontally || isCriticalUpdate || !isScrolling else {
            return
        }
        hasPendingContentSizeUpdate = false
        let oldContentOffset = textView.contentOffset
        textView.contentSize = contentSize
        textView.contentOffset = oldContentOffset
        textView.setNeedsLayout()
    }
}
