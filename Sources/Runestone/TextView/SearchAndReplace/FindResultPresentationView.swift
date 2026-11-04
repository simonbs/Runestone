import UIKit

final class FindResultPresentationView: UIView {
    var isActive = false {
        didSet {
            guard isActive != oldValue else {
                return
            }
            isHidden = !isActive
            selectedResultPlateView.isHidden = !isActive
            if !isActive {
                selectedRange = nil
                currentBounds = .null
                currentRanges = []
                cachedPresentations = []
            }
        }
    }
    let selectedResultPlateView = UIView()

    private weak var sourceView: UIView?
    private let dimmingLayer = CAShapeLayer()
    private var selectedRange: NSRange?
    private var currentBounds = CGRect.null
    private var currentRanges: [HighlightedRange] = []
    private var cachedPresentations: [RangePresentation] = []

    init(sourceView: UIView) {
        self.sourceView = sourceView
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .clear
        dimmingLayer.fillColor = UIColor.black.withAlphaComponent(0.22).cgColor
        dimmingLayer.fillRule = .evenOdd
        layer.addSublayer(dimmingLayer)
        selectedResultPlateView.isHidden = true
        selectedResultPlateView.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(highlightedRanges: [HighlightedRange],
                selectionRects: (UITextRange) -> [UITextSelectionRect]) {
        guard isActive, let sourceView else {
            return
        }
        let searchRanges = highlightedRanges.filter { $0.presentationRole != .standard }
        let selected = searchRanges.first { $0.presentationRole == .selectedSearchResult }
        let shouldAnimate = selectedRange != nil && selected?.range != selectedRange
        let boundsChanged = currentBounds != sourceView.bounds
        let rangesChanged = currentRanges != searchRanges
        guard boundsChanged || rangesChanged else {
            return
        }
        let geometryChanged = boundsChanged || currentRanges.map(\.range) != searchRanges.map(\.range)
        currentBounds = sourceView.bounds
        currentRanges = searchRanges
        frame = sourceView.bounds
        dimmingLayer.frame = bounds
        if geometryChanged {
            cachedPresentations = presentations(for: searchRanges,
                                                sourceView: sourceView,
                                                selectionRects: selectionRects)
        } else {
            cachedPresentations = zip(searchRanges, cachedPresentations).map { range, presentation in
                RangePresentation(range: range, rects: presentation.rects)
            }
        }
        updateDimming()
        updateSelectedResultPlate(animated: shouldAnimate)
        selectedRange = selected?.range
    }

    func updateLayoutIfNeeded(highlightedRanges: [HighlightedRange],
                              selectionRects: (UITextRange) -> [UITextSelectionRect]) {
        guard sourceView?.bounds != currentBounds else {
            return
        }
        update(highlightedRanges: highlightedRanges, selectionRects: selectionRects)
    }

    private func presentations(for ranges: [HighlightedRange],
                               sourceView: UIView,
                               selectionRects: (UITextRange) -> [UITextSelectionRect]) -> [RangePresentation] {
        guard let textInput = sourceView as? UITextInput else {
            return []
        }
        return ranges.compactMap { highlightedRange in
            guard let start = textInput.position(from: textInput.beginningOfDocument,
                                                 offset: highlightedRange.range.location),
                  let end = textInput.position(from: start, offset: highlightedRange.range.length),
                  let textRange = textInput.textRange(from: start, to: end) else {
                return nil
            }
            return RangePresentation(range: highlightedRange, rects: selectionRects(textRange).map(\.rect))
        }
    }

    private func updateDimming() {
        let path = UIBezierPath(rect: bounds)
        for presentation in cachedPresentations {
            for rect in displayRects(for: presentation) where !rect.isEmpty {
                path.append(UIBezierPath(roundedRect: rect,
                                         cornerRadius: cornerRadius(for: presentation.range)))
            }
        }
        dimmingLayer.path = path.cgPath
    }

    private func updateSelectedResultPlate(animated: Bool) {
        selectedResultPlateView.subviews.forEach { $0.removeFromSuperview() }
        guard let presentation = cachedPresentations.first(where: { presentation in
            presentation.range.presentationRole == .selectedSearchResult
        }) else {
            selectedResultPlateView.isHidden = true
            return
        }
        let rects = presentation.rects.filter { !$0.isEmpty }.map(selectedDisplayRect(for:))
        guard !rects.isEmpty else {
            selectedResultPlateView.isHidden = true
            return
        }
        selectedResultPlateView.isHidden = false
        let union = rects.reduce(CGRect.null) { $0.union($1) }
        selectedResultPlateView.frame = union
        for rect in rects {
            let plate = UIView(frame: rect.offsetBy(dx: -union.minX, dy: -union.minY))
            plate.isUserInteractionEnabled = false
            plate.backgroundColor = presentation.range.color
            plate.layer.cornerRadius = Self.selectedCornerRadius
            plate.layer.cornerCurve = .continuous
            plate.layer.shadowColor = UIColor.black.cgColor
            plate.layer.shadowOpacity = 0.22
            plate.layer.shadowRadius = 8
            plate.layer.shadowOffset = CGSize(width: 0, height: 3)
            plate.layer.shadowPath = UIBezierPath(roundedRect: plate.bounds,
                                                  cornerRadius: Self.selectedCornerRadius).cgPath
            selectedResultPlateView.addSubview(plate)
        }
        animateSelectedResultPlate(animated)
    }

    private func animateSelectedResultPlate(_ animated: Bool) {
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            selectedResultPlateView.transform = .identity
            return
        }
        selectedResultPlateView.transform = CGAffineTransform(scaleX: 1.2, y: 1.1)
        let animator = UIViewPropertyAnimator(duration: 0.18, dampingRatio: 0.86) {
            self.selectedResultPlateView.transform = .identity
        }
        animator.startAnimation()
    }

    private func displayRects(for presentation: RangePresentation) -> [CGRect] {
        presentation.range.presentationRole == .selectedSearchResult
            ? presentation.rects.map(selectedDisplayRect(for:))
            : presentation.rects
    }

    private func selectedDisplayRect(for sourceRect: CGRect) -> CGRect {
        sourceRect.insetBy(dx: -Self.selectedHorizontalPadding, dy: -Self.selectedVerticalPadding)
    }

    private func cornerRadius(for range: HighlightedRange) -> CGFloat {
        range.presentationRole == .selectedSearchResult ? Self.selectedCornerRadius : range.cornerRadius
    }

    private static let selectedHorizontalPadding: CGFloat = 4
    private static let selectedVerticalPadding: CGFloat = 3
    private static let selectedCornerRadius: CGFloat = 5
}

private struct RangePresentation {
    let range: HighlightedRange
    let rects: [CGRect]
}
