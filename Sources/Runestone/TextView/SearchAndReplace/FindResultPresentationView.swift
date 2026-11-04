import UIKit

final class FindResultPresentationView: UIView {
    var isActive = false {
        didSet {
            guard isActive != oldValue else {
                return
            }
            isHidden = !isActive
            if !isActive {
                selectedResultContainer.removeFromSuperview()
                selectedRange = nil
                currentViewport = .null
                currentRanges = []
            }
        }
    }

    private weak var sourceView: UIView?
    private let dimmingLayer = CAShapeLayer()
    private let selectedResultContainer = UIView()
    private var selectedRange: NSRange?
    private var currentViewport = CGRect.null
    private var currentRanges: [HighlightedRange] = []

    init(sourceView: UIView) {
        self.sourceView = sourceView
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .clear
        dimmingLayer.fillColor = UIColor.black.withAlphaComponent(0.22).cgColor
        dimmingLayer.fillRule = .evenOdd
        layer.addSublayer(dimmingLayer)
        selectedResultContainer.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(highlightedRanges: [HighlightedRange],
                viewport: CGRect,
                selectionRects: (UITextRange) -> [UITextSelectionRect]) {
        guard isActive, let sourceView else {
            return
        }
        let searchRanges = highlightedRanges.filter { $0.presentationRole != .standard }
        let selected = searchRanges.first { $0.presentationRole == .selectedSearchResult }
        let shouldAnimate = selectedRange != nil && selected?.range != selectedRange
        let needsRebuild = currentViewport != viewport || currentRanges != searchRanges
        guard needsRebuild else {
            return
        }
        currentViewport = viewport
        currentRanges = searchRanges
        frame = viewport
        dimmingLayer.frame = bounds
        let presentations = presentations(for: searchRanges,
                                          sourceView: sourceView,
                                          viewport: viewport,
                                          selectionRects: selectionRects)
        updateDimming(using: presentations)
        selectedResultContainer.removeFromSuperview()
        selectedResultContainer.subviews.forEach { $0.removeFromSuperview() }
        if let selectedPresentation = presentations.first(where: { $0.range.presentationRole == .selectedSearchResult }) {
            updateSelectedResult(using: selectedPresentation, sourceView: sourceView, viewport: viewport)
            animateSelectedResult(shouldAnimate)
        }
        selectedRange = selected?.range
    }

    private func presentations(for ranges: [HighlightedRange],
                               sourceView: UIView,
                               viewport: CGRect,
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
            let rects = selectionRects(textRange).map { selectionRect in
                selectionRect.rect.offsetBy(dx: -viewport.minX, dy: -viewport.minY)
            }
            return RangePresentation(range: highlightedRange, rects: rects)
        }
    }

    private func updateDimming(using presentations: [RangePresentation]) {
        let path = UIBezierPath(rect: bounds)
        for presentation in presentations {
            for rect in presentation.rects where !rect.isEmpty && rect.intersects(bounds) {
                path.append(UIBezierPath(roundedRect: rect, cornerRadius: presentation.range.cornerRadius))
            }
        }
        dimmingLayer.path = path.cgPath
    }

    private func updateSelectedResult(using presentation: RangePresentation,
                                      sourceView: UIView,
                                      viewport: CGRect) {
        let visibleRects = presentation.rects.filter { !$0.isEmpty && $0.intersects(bounds) }
        guard !visibleRects.isEmpty else {
            return
        }
        addSubview(selectedResultContainer)
        let union = visibleRects.reduce(CGRect.null) { $0.union($1) }
        selectedResultContainer.frame = union
        let presentationSuperview = superview
        removeFromSuperview()
        for rect in visibleRects {
            addSelectedResultSnapshot(for: rect,
                                      sourceView: sourceView,
                                      viewport: viewport,
                                      cornerRadius: presentation.range.cornerRadius,
                                      union: union)
        }
        if let presentationSuperview {
            presentationSuperview.addSubview(self)
        }
    }

    private func addSelectedResultSnapshot(for rect: CGRect,
                                           sourceView: UIView,
                                           viewport: CGRect,
                                           cornerRadius: CGFloat,
                                           union: CGRect) {
        let sourceRect = rect.offsetBy(dx: viewport.minX, dy: viewport.minY)
        guard let snapshot = sourceView.resizableSnapshotView(from: sourceRect,
                                                              afterScreenUpdates: true,
                                                              withCapInsets: .zero) else {
            return
        }
        let shadowView = UIView(frame: rect.offsetBy(dx: -union.minX, dy: -union.minY))
        shadowView.isUserInteractionEnabled = false
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.22
        shadowView.layer.shadowRadius = 8
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 3)
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: shadowView.bounds, cornerRadius: cornerRadius).cgPath
        snapshot.frame = shadowView.bounds
        snapshot.layer.cornerRadius = cornerRadius
        snapshot.layer.cornerCurve = .continuous
        snapshot.clipsToBounds = true
        shadowView.addSubview(snapshot)
        selectedResultContainer.addSubview(shadowView)
    }

    private func animateSelectedResult(_ animated: Bool) {
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            selectedResultContainer.transform = .identity
            return
        }
        selectedResultContainer.transform = CGAffineTransform(scaleX: 1.2, y: 1.1)
        let animator = UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.82) {
            self.selectedResultContainer.transform = .identity
        }
        animator.startAnimation()
    }
}

private struct RangePresentation {
    let range: HighlightedRange
    let rects: [CGRect]
}
