import Foundation
import LineManager
import MultiPlatform
import RangeHelpers
import StringView

final class LineSelectionLayoutManager {
    var showLineSelection = false {
        didSet {
            if showLineSelection != oldValue {
                setNeedsLayout()
                updateVisibility()
            }
        }
    }
    var selectEntireLine = false {
        didSet {
            if selectEntireLine != oldValue {
                setNeedsLayout()
            }
        }
    }
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                setNeedsLayout()
            }
        }
    }
    var textContainerInset: MultiPlatformEdgeInsets = .zero {
        didSet {
            if textContainerInset != oldValue {
                setNeedsLayout()
            }
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
    var backgroundColor: MultiPlatformColor? {
        didSet {
            if backgroundColor != oldValue {
                lineSelectionView.backgroundColor = backgroundColor
            }
        }
    }

    private let stringView: StringView
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private weak var containerView: MultiPlatformView?
    private let lineSelectionView = MultiPlatformView()
    private var needsLayout = false

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage, containerView: MultiPlatformView) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.containerView = containerView
        lineSelectionView.layerIfLoaded?.zPosition = -1000
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

private extension LineSelectionLayoutManager {
    private func updateVisibility() {
        lineSelectionView.isHidden = !showLineSelection || (selectedRange?.length ?? 0) > 0
    }

    private func getLineSelectionRect() -> CGRect? {
        guard let selectedRange = selectedRange?.nonNegativeLength else {
            return nil
        }
        if selectEntireLine {
            return getEntireLineSelectionRect(in: selectedRange)
        } else {
            return getLineFragmentSelectionRect(in: selectedRange)
        }
    }

    private func getEntireLineSelectionRect(in range: NSRange) -> CGRect? {
        guard let containerView else {
            return nil
        }
        guard let (startLine, endLine) = lineManager.startAndEndLine(in: range) else {
            return nil
        }
        let minY = startLine.yPosition
        let height = (endLine.yPosition + endLine.data.lineHeight) - minY
        return CGRect(x: 0, y: textContainerInset.top + minY, width: containerView.frame.width, height: height)
    }

    private func getLineFragmentSelectionRect(in range: NSRange) -> CGRect? {
        guard let containerView else {
            return nil
        }
        let caretRectFactory = CaretRectFactory(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            textContainerInset: textContainerInset
        )
        let startCaretRect = caretRectFactory.caretRect(at: range.lowerBound, allowMovingCaretToNextLineFragment: true)
        let endCaretRect = caretRectFactory.caretRect(at: range.upperBound, allowMovingCaretToNextLineFragment: true)
        let startLineFragmentHeight = startCaretRect.height * lineHeightMultiplier
        let endLineFragmentHeight = endCaretRect.height * lineHeightMultiplier
        let minY = startCaretRect.minY - (startLineFragmentHeight - startCaretRect.height) / 2
        let maxY = endCaretRect.maxY + (endLineFragmentHeight - endCaretRect.height) / 2
        return CGRect(x: 0, y: minY, width: containerView.frame.width, height: maxY - minY)
    }
}
