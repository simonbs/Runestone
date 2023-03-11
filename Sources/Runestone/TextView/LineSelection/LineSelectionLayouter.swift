import Combine
import Foundation

final class LineSelectionLayouter {
    var lineSelectionDisplayType: LineSelectionDisplayType = .disabled {
        didSet {
            updateVisibility()
            setNeedsLayout()
        }
    }
    var selectedRange: NSRange? {
        didSet {
            if selectedRange != oldValue {
                setNeedsLayout()
                updateVisibility()
            }
        }
    }

    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let caretRectProvider: CaretRectProvider
    private let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    private let lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    private weak var containerView: MultiPlatformView?
    private let lineSelectionView = MultiPlatformView()
    private var needsLayout = false
    private var cancellables: Set<AnyCancellable> = []

    init(
        lineManager: CurrentValueSubject<LineManager, Never>,
        caretRectProvider: CaretRectProvider,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>,
        backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
        containerView: MultiPlatformView
    ) {
        self.lineManager = lineManager
        self.caretRectProvider = caretRectProvider
        self.textContainerInset = textContainerInset
        self.lineHeightMultiplier = lineHeightMultiplier
        self.containerView = containerView
        lineSelectionView.layerIfLoaded?.zPosition = -1000
        backgroundColor.sink { [weak self] color in
            self?.lineSelectionView.backgroundColor = color
        }.store(in: &cancellables)
    }

    func setNeedsLayout() {
        needsLayout = true
    }

    func layoutIfNeeded() {
        guard needsLayout else {
            return
        }
        needsLayout = false
        if let frame = getLineSelectionRect() {
            lineSelectionView.frame = frame
        }
        if lineSelectionView.superview == nil {
            containerView?.addSubview(lineSelectionView)
        }
    }
}

private extension LineSelectionLayouter {
    private func updateVisibility() {
        lineSelectionView.isHidden = lineSelectionDisplayType == .disabled || (selectedRange?.length ?? 0) > 0
    }

    private func getLineSelectionRect() -> CGRect? {
        guard let selectedRange = selectedRange?.nonNegativeLength else {
            return nil
        }
        switch lineSelectionDisplayType {
        case .line:
            return getEntireLineSelectionRect(in: selectedRange)
        case .lineFragment:
            return getLineFragmentSelectionRect(in: selectedRange)
        case .disabled:
            return nil
        }
    }

    private func getEntireLineSelectionRect(in range: NSRange) -> CGRect? {
        guard let containerView else {
            return nil
        }
        guard let (startLine, endLine) = lineManager.value.startAndEndLine(in: range) else {
            return nil
        }
        let minY = startLine.yPosition
        let height = (endLine.yPosition + endLine.data.lineHeight) - minY
        let origin = CGPoint(x: 0, y: textContainerInset.value.top + minY)
        let size = CGSize(width: containerView.frame.width, height: height)
        return CGRect(origin: origin, size: size)
    }

    private func getLineFragmentSelectionRect(in range: NSRange) -> CGRect? {
        guard let containerView else {
            return nil
        }
        let startCaretRect = caretRectProvider.caretRect(at: range.lowerBound, allowMovingCaretToNextLineFragment: true)
        let endCaretRect = caretRectProvider.caretRect(at: range.upperBound, allowMovingCaretToNextLineFragment: true)
        let startLineFragmentHeight = startCaretRect.height * lineHeightMultiplier.value
        let endLineFragmentHeight = endCaretRect.height * lineHeightMultiplier.value
        let minY = startCaretRect.minY - (startLineFragmentHeight - startCaretRect.height) / 2
        let maxY = endCaretRect.maxY + (endLineFragmentHeight - endCaretRect.height) / 2
        return CGRect(x: 0, y: minY, width: containerView.frame.width, height: maxY - minY)
    }
}

private extension LineSelectionLayouter {
    private func setupSetNeedsLayoutObserver() {
        Publishers.CombineLatest(textContainerInset, lineHeightMultiplier).sink { [weak self] _ in
            self?.setNeedsLayout()
        }.store(in: &cancellables)
    }
}
