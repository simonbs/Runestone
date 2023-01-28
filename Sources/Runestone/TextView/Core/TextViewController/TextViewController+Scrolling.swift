import Foundation

 extension TextViewController {
    func scrollRangeToVisible(_ range: NSRange) {
        layoutManager.layoutLines(toLocation: range.upperBound)
        justScrollRangeToVisible(range)
    }

    func scrollLocationToVisible(_ location: Int) {
        let range = NSRange(location: location, length: 0)
        justScrollRangeToVisible(range)
    }
}

private extension TextViewController {
    private func justScrollRangeToVisible(_ range: NSRange) {
        let lowerBoundRect = caretRect(at: range.lowerBound)
        let upperBoundRect = range.length == 0 ? lowerBoundRect : caretRect(at: range.upperBound)
        let rectMinX = min(lowerBoundRect.minX, upperBoundRect.minX)
        let rectMaxX = max(lowerBoundRect.maxX, upperBoundRect.maxX)
        let rectMinY = min(lowerBoundRect.minY, upperBoundRect.minY)
        let rectMaxY = max(lowerBoundRect.maxY, upperBoundRect.maxY)
        let rect = CGRect(x: rectMinX, y: rectMinY, width: rectMaxX - rectMinX, height: rectMaxY - rectMinY)
        textView.contentOffset = contentOffsetForScrollingToVisibleRect(rect)
    }

    private func caretRect(at location: Int) -> CGRect {
        caretRectService.caretRect(at: location, allowMovingCaretToNextLineFragment: true)
    }

    /// Computes a content offset to scroll to in order to reveal the specified rectangle.
    ///
    /// The function will return a rectangle that scrolls the text view a minimum amount while revealing as much as possible of the rectangle. It is not guaranteed that the entire rectangle can be revealed.
    /// - Parameter rect: The rectangle to reveal.
    /// - Returns: The content offset to scroll to.
    private func contentOffsetForScrollingToVisibleRect(_ rect: CGRect) -> CGPoint {
        // Create the viewport: a rectangle containing the content that is visible to the user.
        var viewport = CGRect(x: textView.contentOffset.x, y: textView.contentOffset.y, width: textView.frame.width, height: textView.frame.height)
        viewport.origin.y += textView.adjustedContentInset.top
        viewport.origin.x += textView.adjustedContentInset.left + gutterWidth
        viewport.size.width -= textView.adjustedContentInset.left + textView.adjustedContentInset.right + gutterWidth
        viewport.size.height -= textView.adjustedContentInset.top + textView.adjustedContentInset.bottom
        // Construct the best possible content offset.
        var newContentOffset = textView.contentOffset
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
        let cappedXOffset = min(max(newContentOffset.x, textView.minimumContentOffset.x), textView.maximumContentOffset.x)
        let cappedYOffset = min(max(newContentOffset.y, textView.minimumContentOffset.y), textView.maximumContentOffset.y)
        return CGPoint(x: cappedXOffset, y: cappedYOffset)
    }
}
