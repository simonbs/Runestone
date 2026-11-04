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
                selectedResultPlateView.layer.removeAnimation(forKey: Self.bounceAnimationKey)
                selectedResultPlateView.transform = .identity
                selectedRange = nil
                currentBounds = .null
                currentRanges = []
                cachedPresentations = []
                selectedTextSegmentSignature = []
            }
        }
    }
    let selectedResultPlateView = UIView()

    private weak var sourceView: UIView?
    private let dimmingLayer = CAShapeLayer()
    private var selectedRange: NSRange?
    private var currentDimmingBounds = CGRect.null
    private var currentBounds = CGRect.null
    private var currentRanges: [HighlightedRange] = []
    private var cachedPresentations: [RangePresentation] = []
    private var selectedTextSegmentSignature: [SelectedResultTextSegmentSignature] = []

    init(sourceView: UIView) {
        self.sourceView = sourceView
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .clear
        dimmingLayer.fillColor = Self.dimmingColor.cgColor
        dimmingLayer.fillRule = .evenOdd
        layer.addSublayer(dimmingLayer)
        selectedResultPlateView.isHidden = true
        selectedResultPlateView.isUserInteractionEnabled = false
        addSubview(selectedResultPlateView)
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
        guard boundsChanged || rangesChanged || dimmingBounds != currentDimmingBounds else {
            return
        }
        let geometryChanged = currentBounds.width != sourceView.bounds.width
            || currentRanges.map(\.range) != searchRanges.map(\.range)
        currentBounds = sourceView.bounds
        currentRanges = searchRanges
        frame = sourceView.bounds
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

    func updateLayoutIfNeeded(selectionRects: (UITextRange) -> [UITextSelectionRect]) {
        guard let sourceView else {
            return
        }
        let dimmingBoundsChanged = dimmingBounds != currentDimmingBounds
        let boundsChanged = sourceView.bounds != currentBounds
        let geometryChanged = sourceView.bounds.width != currentBounds.width
        if boundsChanged {
            currentBounds = sourceView.bounds
            frame = sourceView.bounds
            if geometryChanged {
                cachedPresentations = presentations(for: currentRanges,
                                                    sourceView: sourceView,
                                                    selectionRects: selectionRects)
            }
        }
        guard let selectedIndex = cachedPresentations.firstIndex(where: { presentation in
            presentation.range.presentationRole == .selectedSearchResult
        }) else {
            if boundsChanged || dimmingBoundsChanged {
                updateDimming()
            }
            return
        }
        let selectedPresentation = cachedPresentations[selectedIndex]
        let refreshedPresentation = presentation(for: selectedPresentation.range,
                                                 sourceView: sourceView,
                                                 selectionRects: selectionRects)
        let selectedSegments = (sourceView as? TextInputView)?.selectedResultTextSegments(
            for: selectedPresentation.range.range
        ) ?? []
        let segmentSignature = selectedSegments.map(SelectedResultTextSegmentSignature.init)
        let selectedGeometryChanged = refreshedPresentation?.rects != selectedPresentation.rects
        if let refreshedPresentation, selectedGeometryChanged {
            cachedPresentations[selectedIndex] = refreshedPresentation
        }
        if boundsChanged || dimmingBoundsChanged || selectedGeometryChanged {
            updateDimming()
        }
        if geometryChanged || selectedGeometryChanged || segmentSignature != selectedTextSegmentSignature {
            updateSelectedResultPlate(animated: false, selectedSegments: selectedSegments)
        }
    }

    private func presentations(for ranges: [HighlightedRange],
                               sourceView: UIView,
                               selectionRects: (UITextRange) -> [UITextSelectionRect]) -> [RangePresentation] {
        guard let textInput = sourceView as? UITextInput else {
            return []
        }
        return ranges.compactMap { highlightedRange in
            presentation(for: highlightedRange, textInput: textInput, selectionRects: selectionRects)
        }
    }

    private func presentation(for range: HighlightedRange,
                              sourceView: UIView,
                              selectionRects: (UITextRange) -> [UITextSelectionRect]) -> RangePresentation? {
        guard let textInput = sourceView as? UITextInput else {
            return nil
        }
        return presentation(for: range, textInput: textInput, selectionRects: selectionRects)
    }

    private func presentation(for range: HighlightedRange,
                              textInput: UITextInput,
                              selectionRects: (UITextRange) -> [UITextSelectionRect]) -> RangePresentation? {
        guard let start = textInput.position(from: textInput.beginningOfDocument, offset: range.range.location),
              let end = textInput.position(from: start, offset: range.range.length),
              let textRange = textInput.textRange(from: start, to: end) else {
            return nil
        }
        return RangePresentation(range: range, rects: selectionRects(textRange).map(\.rect))
    }

    private var dimmingBounds: CGRect {
        // The viewport includes adjusted content insets and scroll bounce regions
        // outside the text content, including the area behind navigation bars.
        let viewport = (sourceView as? TextInputView)?.viewport ?? bounds
        return bounds.union(viewport)
    }

    private func updateDimming() {
        let coverage = dimmingBounds
        let path = UIBezierPath(rect: CGRect(origin: .zero, size: coverage.size))
        for presentation in cachedPresentations {
            for rect in displayRects(for: presentation) where !rect.isEmpty {
                path.append(UIBezierPath(roundedRect: rect.offsetBy(dx: -coverage.minX, dy: -coverage.minY),
                                         cornerRadius: cornerRadius(for: presentation.range)))
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimmingLayer.frame = coverage
        dimmingLayer.path = path.cgPath
        currentDimmingBounds = coverage
        CATransaction.commit()
    }

    private func updateSelectedResultPlate(animated: Bool, selectedSegments: [SelectedResultTextSegment]? = nil) {
        selectedResultPlateView.subviews.forEach { $0.removeFromSuperview() }
        selectedTextSegmentSignature = []
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
        let segments = selectedSegments
            ?? (sourceView as? TextInputView)?.selectedResultTextSegments(for: presentation.range.range)
            ?? []
        selectedTextSegmentSignature = segments.map(SelectedResultTextSegmentSignature.init)
        if sourceView is TextInputView {
            for segment in segments {
                let textView = SelectedResultTextView(segment: segment,
                                                      foregroundColor: presentation.range.foregroundColor)
                textView.frame = segment.frame.offsetBy(dx: -union.minX, dy: -union.minY)
                selectedResultPlateView.addSubview(textView)
            }
        }
        animateSelectedResultPlate(animated)
    }

    private func animateSelectedResultPlate(_ animated: Bool) {
        guard animated else {
            return
        }
        selectedResultPlateView.layer.removeAnimation(forKey: Self.bounceAnimationKey)
        selectedResultPlateView.transform = .identity
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1, 1.13, 0.985, 1]
        animation.keyTimes = [0, 0.38, 0.76, 1]
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut)
        ]
        animation.duration = 0.24
        selectedResultPlateView.layer.add(animation, forKey: Self.bounceAnimationKey)
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

    static let dimmingColor = UIColor.black.withAlphaComponent(0.22)

    private static let selectedHorizontalPadding: CGFloat = 4
    private static let selectedVerticalPadding: CGFloat = 3
    private static let selectedCornerRadius: CGFloat = 5
    static let bounceAnimationKey = "find-result-bounce"
}

struct SelectedResultTextSegment {
    let frame: CGRect
    let horizontalOffset: CGFloat
    let renderer: LineFragmentRenderer
}

private struct SelectedResultTextSegmentSignature: Equatable {
    let frame: CGRect
    let horizontalOffset: CGFloat
    let renderer: ObjectIdentifier

    init(segment: SelectedResultTextSegment) {
        frame = segment.frame
        horizontalOffset = segment.horizontalOffset
        renderer = ObjectIdentifier(segment.renderer)
    }
}

private final class SelectedResultTextView: UIView {
    private let segment: SelectedResultTextSegment
    private let foregroundColor: UIColor?

    init(segment: SelectedResultTextSegment, foregroundColor: UIColor?) {
        self.segment = segment
        self.foregroundColor = foregroundColor
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.translateBy(x: -segment.horizontalOffset, y: 0)
        segment.renderer.drawText(to: context, excludingHiddenRanges: false, foregroundColor: foregroundColor)
    }
}

private struct RangePresentation {
    let range: HighlightedRange
    let rects: [CGRect]
}
