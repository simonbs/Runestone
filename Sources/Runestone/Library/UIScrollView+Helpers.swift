import UIKit

extension UIScrollView {
    var minimumContentOffset: CGPoint {
        CGPoint(x: adjustedContentInset.left * -1, y: adjustedContentInset.top * -1)
    }

    var maximumContentOffset: CGPoint {
        let maxX = max(contentSize.width - bounds.width + adjustedContentInset.right, adjustedContentInset.left * -1)
        let maxY = max(contentSize.height - bounds.height + adjustedContentInset.bottom, adjustedContentInset.top * -1)
        return CGPoint(x: maxX, y: maxY)
    }
}
