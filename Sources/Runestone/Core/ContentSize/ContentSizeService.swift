import _RunestoneMultiPlatform
import _RunestoneObservation
import CoreGraphics
import Foundation

@RunestoneObserver
final class ContentSizeService<LineManagerType: LineManaging> {
    typealias State = TextContainerInsetReadable
    & IsLineWrappingEnabledReadable
    & InsertionPointShapeReadable
    & OverscrollFactorReadable
    & EstimatedCharacterWidthReadable
    & EstimatedLineHeightReadable
    & InvisibleCharacterConfigurationReadable

    private let state: State
    private weak var scrollView: MultiPlatformScrollView?
    private let viewport: Viewport
    private let lineManager: LineManagerType
    private var lineIdTrackedForWidth: LineID?
    private var lineSizes: [LineID: CGSize] = [:]
    private var hasPendingContentSizeUpdate = false
    private var longestLineWidth: CGFloat {
        if let lineIdTrackedForWidth, let lineSize = lineSizes[lineIdTrackedForWidth] {
            return lineSize.width
        } else {
            lineIdTrackedForWidth = nil
            var longestLineWidth: CGFloat = 0
            for (lineID, lineSize) in lineSizes {
                if lineSize.width > longestLineWidth {
                    lineIdTrackedForWidth = lineID
                    longestLineWidth = lineSize.width
                }
            }
            return longestLineWidth
        }
    }
    private var cachedTotalLineHeight: CGFloat?
    private var totalLineHeight: CGFloat {
        if let cachedTotalLineHeight {
            return cachedTotalLineHeight
        } else {
            let estimatedHeight = state.estimatedLineHeight * CGFloat(lineManager.lineCount - lineSizes.count)
            let observedHeight = lineSizes.values.reduce(0) { $0 + $1.height }
            let result = estimatedHeight + observedHeight
            cachedTotalLineHeight = result
            return result
        }
    }
    private var contentWidth: CGFloat {
        guard !state.isLineWrappingEnabled else {
            return viewport.width
        }
        let preferredWidth = longestLineWidth
        + max(state.maximumLineBreakSymbolWidth, insertionPointWidth)
        + state.textContainerInset.left + state.textContainerInset.right
        + viewport.width * state.horizontalOverscrollFactor
        return max(preferredWidth, viewport.width)
    }
    private var contentHeight: CGFloat {
        let totalTextContainerInset = state.textContainerInset.top + state.textContainerInset.bottom
        let overscrollAmount = viewport.height * state.verticalOverscrollFactor
        let preferredHeight = totalLineHeight + totalTextContainerInset + overscrollAmount
        return max(preferredHeight, viewport.height)
    }
    private var allowsContentSizeUpdate: Bool {
        guard let view = scrollView else {
            return false
        }
        // We don't want to update the content size when the scroll view is "bouncing" near the gutter,
        // or at the end of a line since it causes flickering when updating the content size while scrolling.
        // However, we do allow updating the content size if the text view is scrolled far enough on
        // the y-axis as that means it will soon run out of text to display.
        let leadingBounceOffset = view.contentInset.left * -1
        let trailingBounceOffset = view.contentSize.width - view.frame.size.width + view.contentInset.right
        let isBouncingAtLeading = view.contentOffset.x < leadingBounceOffset
        let isBouncingAtTrailing = view.contentOffset.x > trailingBounceOffset
        let isBouncingHorizontally = isBouncingAtLeading || isBouncingAtTrailing
        let criticalYContentOffset = view.contentSize.height - view.frame.height * 1.5
        let isCriticalUpdate = view.contentOffset.y > criticalYContentOffset
        let isScrolling = view.isDragging || view.isDecelerating
        return !isBouncingHorizontally || isCriticalUpdate || !isScrolling
    }
    private var insertionPointWidth: CGFloat {
        switch state.insertionPointShape {
        case .underline, .block:
            return state.estimatedCharacterWidth
        case .verticalBar:
            return 0
        }
    }

    init(state: State, scrollView: MultiPlatformScrollView, viewport: Viewport, lineManager: LineManagerType) {
        self.scrollView = scrollView
        self.state = state
        self.viewport = viewport
        self.lineManager = lineManager
        observe(state.textContainerInset) { [unowned self] _, _ in
            hasPendingContentSizeUpdate = true
            updateContentSizeIfNeeded()
        }
        observe(state.horizontalOverscrollFactor) { [unowned self] _, _ in
            hasPendingContentSizeUpdate = true
            updateContentSizeIfNeeded()
        }
        observe(state.verticalOverscrollFactor) { [unowned self] _, _ in
            hasPendingContentSizeUpdate = true
            updateContentSizeIfNeeded()
        }
        observe(state.isLineWrappingEnabled) { [unowned self] _, _ in
            hasPendingContentSizeUpdate = true
            updateContentSizeIfNeeded()
        }
        observe(state.insertionPointShape) { [unowned self] _, _ in
            hasPendingContentSizeUpdate = true
            updateContentSizeIfNeeded()
        }
        observe(state.estimatedCharacterWidth) { [unowned self] _, _ in
            hasPendingContentSizeUpdate = true
            updateContentSizeIfNeeded()
        }
        observe(viewport.size) { [unowned self] _, _ in
            updateContentSizeIfNeeded()
        }
        observe(viewport.size) { [unowned self] _, _ in
            updateContentSizeIfNeeded()
        }
    }

    func setSize(_ size: CGSize, ofLineWithID lineID: LineID) {
        let oldValue = lineSizes[lineID]
        lineSizes[lineID] = size
        if size.height != oldValue?.height {
            cachedTotalLineHeight = nil
            hasPendingContentSizeUpdate = true
        }
        if let lineIdTrackedForWidth, let lineSize = lineSizes[lineIdTrackedForWidth], size.width > lineSize.width {
            self.lineIdTrackedForWidth = lineID
            hasPendingContentSizeUpdate = true
        } else if lineID == lineIdTrackedForWidth || lineIdTrackedForWidth == nil {
            hasPendingContentSizeUpdate = true
        }
        updateContentSizeIfNeeded()
    }

    func removeLine(withID lineID: LineID) {
        if lineSizes.removeValue(forKey: lineID) != nil {
            cachedTotalLineHeight = nil
            hasPendingContentSizeUpdate = true
        }
        if lineID == lineIdTrackedForWidth {
            lineIdTrackedForWidth = nil
            hasPendingContentSizeUpdate = true
        }
        updateContentSizeIfNeeded()
    }
}

private extension ContentSizeService {
    private func updateContentSizeIfNeeded() {
        guard let scrollView, hasPendingContentSizeUpdate else {
            return
        }
        guard allowsContentSizeUpdate else {
            return
        }
        hasPendingContentSizeUpdate = false
        let oldContentOffset = scrollView.contentOffset
        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
        scrollView.contentOffset = oldContentOffset
        print("📜 \(scrollView.contentSize)")
    }
}
