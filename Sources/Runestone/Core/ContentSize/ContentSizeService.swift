import Combine
import CoreGraphics

final class ContentSizeService {
//    let contentSize = CurrentValueSubject<CGSize, Never>(.zero)
//    let horizontalOverscrollFactor = CurrentValueSubject<CGFloat, Never>(1)
//    let verticalOverscrollFactor = CurrentValueSubject<CGFloat, Never>(1)

//    private let proxyScrollView: ProxyScrollView
//    private let totalLineHeightTracker: TotalLineHeightTracker
//    private let widestLineTracker: WidestLineTracker
//    private let viewport: CurrentValueSubject<CGRect, Never>
//    private let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
//    private let isLineWrappingEnabled: CurrentValueSubject<Bool, Never>
//    private let maximumLineBreakSymbolWidth: CurrentValueSubject<CGFloat, Never>
//    private let estimatedCharacterWidth: EstimatedCharacterWidth
//    private let insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
//    private var cancellables: Set<AnyCancellable> = []
//    private var hasPendingContentSizeUpdate = false
//    private var contentWidth: CGFloat {
//        guard let lineWidth = widestLineTracker.lineWidth else {
//            return 0
//        }
//        let preferredWidth = lineWidth
//        + max(lineBreakInvisibleCharacterWidth, insertionPointWidth)
//        + textContainerInset.value.left + textContainerInset.value.right
//        + viewport.value.width * horizontalOverscrollFactor.value
//        return max(preferredWidth, viewport.value.width)
//    }
//    private var contentHeight: CGFloat {
//        let totalTextContainerInset = textContainerInset.value.top + textContainerInset.value.bottom
//        let overscrollAmount = viewport.value.height * verticalOverscrollFactor.value
//        let preferredHeight = totalLineHeightTracker.totalLineHeight + totalTextContainerInset + overscrollAmount
//        return max(preferredHeight, viewport.value.height)
//    }
//    private var lineBreakInvisibleCharacterWidth: CGFloat {
//        maximumLineBreakSymbolWidth.value
//    }
//    private var insertionPointWidth: CGFloat {
//        switch insertionPointShape.value {
//        case .underline, .block:
//            return estimatedCharacterWidth.rawValue.value
//        case .verticalBar:
//            return 0
//        }
//    }

    init() {}

//    init(
//        proxyScrollView: ProxyScrollView,
//        totalLineHeightTracker: TotalLineHeightTracker,
//        widestLineTracker: WidestLineTracker,
//        viewport: CurrentValueSubject<CGRect, Never>,
//        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
//        isLineWrappingEnabled: CurrentValueSubject<Bool, Never>,
//        maximumLineBreakSymbolWidth: CurrentValueSubject<CGFloat, Never>,
//        estimatedCharacterWidth: EstimatedCharacterWidth,
//        insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
//    ) {
//        self.proxyScrollView = proxyScrollView
//        self.totalLineHeightTracker = totalLineHeightTracker
//        self.widestLineTracker = widestLineTracker
//        self.viewport = viewport
//        self.textContainerInset = textContainerInset
//        self.isLineWrappingEnabled = isLineWrappingEnabled
//        self.maximumLineBreakSymbolWidth = maximumLineBreakSymbolWidth
//        self.estimatedCharacterWidth = estimatedCharacterWidth
//        self.insertionPointShape = insertionPointShape
//        setupHasPendingContentSizeUpdateSetters()
//    }

    func updateContentSizeIfNeeded() {
//        guard let scrollView = proxyScrollView.scrollView, hasPendingContentSizeUpdate else {
//            return
//        }
        // We don't want to update the content size when the scroll view is "bouncing" near the gutter,
        // or at the end of a line since it causes flickering when updating the content size while scrolling.
        // However, we do allow updating the content size if the text view is scrolled far enough on
        // the y-axis as that means it will soon run out of text to display.
//        let gutterBounceOffset = scrollView.contentInset.left * -1
//        let lineEndBounceOffset = scrollView.contentSize.width - scrollView.frame.size.width + scrollView.contentInset.right
//        let isBouncingAtGutter = scrollView.contentOffset.x < gutterBounceOffset
//        let isBouncingAtLineEnd = scrollView.contentOffset.x > lineEndBounceOffset
//        let isBouncingHorizontally = isBouncingAtGutter || isBouncingAtLineEnd
//        let isCriticalUpdate = scrollView.contentOffset.y > scrollView.contentSize.height - scrollView.frame.height * 1.5
//        let isScrolling = scrollView.isDragging || scrollView.isDecelerating
//        guard !isBouncingHorizontally || isCriticalUpdate || !isScrolling else {
//            return
//        }
//        hasPendingContentSizeUpdate = false
//        let oldContentOffset = scrollView.contentOffset
//        scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)
//        scrollView.contentOffset = oldContentOffset
//        contentSize.value = CGSize(width: contentWidth, height: contentHeight)
    }
}

private extension ContentSizeService {
    private func setupHasPendingContentSizeUpdateSetters() {
//        Publishers.MergeMany(
//            widestLineTracker.$isLineWidthInvalid.filter { $0 }.eraseToAnyPublisher(),
//            totalLineHeightTracker.$isTotalLineHeightInvalid.filter { $0 }.eraseToAnyPublisher(),
//            viewport.map(\.size).removeDuplicates().map { _ in true }.eraseToAnyPublisher(),
//            isLineWrappingEnabled.removeDuplicates().map { _ in true }.eraseToAnyPublisher(),
//            horizontalOverscrollFactor.removeDuplicates().map { _ in true }.eraseToAnyPublisher(),
//            verticalOverscrollFactor.removeDuplicates().map { _ in true }.eraseToAnyPublisher(),
//            maximumLineBreakSymbolWidth.removeDuplicates().map { _ in true }.eraseToAnyPublisher(),
//            estimatedCharacterWidth.rawValue.removeDuplicates().map { _ in true }.eraseToAnyPublisher(),
//            insertionPointShape.removeDuplicates().map { _ in true }.eraseToAnyPublisher()
//        ).sink { [weak self] _ in
//            self?.hasPendingContentSizeUpdate = true
//        }.store(in: &cancellables)
    }
}
