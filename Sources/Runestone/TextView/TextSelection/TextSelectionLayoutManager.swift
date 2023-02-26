#if os(macOS)
import Foundation

final class TextSelectionLayoutManager {
    var selectedRange: NSRange? {
        didSet {
            if selectedRange != oldValue {
                updateSelectedRectangles()
            }
        }
    }
    var textContainerInset: MultiPlatformEdgeInsets = .zero {
        didSet {
            if textContainerInset != oldValue {
                updateSelectedRectangles()
            }
        }
    }
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                updateSelectedRectangles()
            }
        }
    }
    var backgroundColor: MultiPlatformColor = .label.withAlphaComponent(0.2) {
        didSet {
            if backgroundColor != oldValue {
                for (_, view) in selectionReusableViewQueue.visibleViews {
                    view.backgroundColor = backgroundColor
                }
            }
        }
    }

    private let stringView: StringView
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private let contentSizeService: ContentSizeService
    private weak var containerView: MultiPlatformView?
    private let selectionReusableViewQueue = ReusableViewQueue<String, LineSelectionView>()

    init(
        stringView: StringView,
        lineManager: LineManager,
        textContainerInset: MultiPlatformEdgeInsets,
        lineControllerStorage: LineControllerStorage,
        contentSizeService: ContentSizeService,
        containerView: MultiPlatformView
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.textContainerInset = textContainerInset
        self.lineControllerStorage = lineControllerStorage
        self.contentSizeService = contentSizeService
        self.containerView = containerView
    }

    func updateSelectedRectangles() {
        guard let selectedRange, selectedRange.length != 0 else {
            removeAllViews()
            return
        }
        let caretRectFactory = CaretRectFactory(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            textContainerInset: textContainerInset
        )
        let textSelectionRectFactory = TextSelectionRectFactory(
            lineManager: lineManager,
            contentSizeService: contentSizeService,
            caretRectFactory: caretRectFactory,
            textContainerInset: textContainerInset,
            lineHeightMultiplier: lineHeightMultiplier
        )
        let selectionRects = textSelectionRectFactory.selectionRects(in: selectedRange)
        addViews(for: selectionRects)
    }
}

private extension TextSelectionLayoutManager {
    private func removeAllViews() {
        for (_, view) in selectionReusableViewQueue.visibleViews {
            view.removeFromSuperview()
        }
        let keys = Set(selectionReusableViewQueue.visibleViews.keys)
        selectionReusableViewQueue.enqueueViews(withKeys: keys)
    }

    private func addViews(for selectionRects: [TextSelectionRect]) {
        var appearedViewKeys = Set<String>()
        for (idx, selectionRect) in selectionRects.enumerated() {
            let key = String(describing: idx)
            let view = selectionReusableViewQueue.dequeueView(forKey: key)
            view.frame = selectionRect.rect
            view.backgroundColor = backgroundColor
            view.layer?.zPosition = 500
            containerView?.addSubview(view)
            appearedViewKeys.insert(key)
        }
        let disappearedViewKeys = Set(selectionReusableViewQueue.visibleViews.keys).subtracting(appearedViewKeys)
        selectionReusableViewQueue.enqueueViews(withKeys: disappearedViewKeys)
    }
}
#endif
