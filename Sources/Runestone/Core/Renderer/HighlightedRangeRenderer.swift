import CoreText

final class HighlightedRangeRenderer: Renderer {
    private let lineFragment: LineFragment
    private let stringProvider: RendererStringProvider
    private let highlightedRangeFragments: [HighlightedRangeFragment]

    init(lineFragment: LineFragment, stringProvider: RendererStringProvider, highlightedRangeFragments: [HighlightedRangeFragment]) {
        self.lineFragment = lineFragment
        self.stringProvider = stringProvider
        self.highlightedRangeFragments = highlightedRangeFragments
    }

    func render() {
        guard !highlightedRangeFragments.isEmpty else {
            return
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.saveGState()
        for highlightedRange in highlightedRangeFragments {
            render(highlightedRange, in: context)
        }
        context.restoreGState()
    }
}

private extension HighlightedRangeRenderer {
    private func render(_ highlightedRange: HighlightedRangeFragment, in context: CGContext) {
        let startX = CTLineGetOffsetForStringIndex(lineFragment.line, highlightedRange.range.lowerBound, nil)
        let endX = endX(for: highlightedRange, in: context)
        let cornerRadius = highlightedRange.cornerRadius
        let rect = CGRect(x: startX, y: 0, width: endX - startX, height: lineFragment.scaledSize.height)
        let roundedPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.setFillColor(highlightedRange.color.cgColor)
        context.addPath(roundedPath)
        context.fillPath()
        // Draw non-rounded edges if needed.
        if !highlightedRange.containsStart {
            let startRect = CGRect(x: 0, y: 0, width: cornerRadius, height: rect.height)
            let startPath = CGPath(rect: startRect, transform: nil)
            context.addPath(startPath)
            context.fillPath()
        }
        if !highlightedRange.containsEnd {
            let endRect = CGRect(x: 0, y: 0, width: rect.width - cornerRadius, height: rect.height)
            let endPath = CGPath(rect: endRect, transform: nil)
            context.addPath(endPath)
            context.fillPath()
        }
    }

    private func endX(for highlightedRange: HighlightedRangeFragment, in context: CGContext) -> CGFloat {
        if shouldHighlightLineEnding(for: highlightedRange) {
            return CGFloat(context.width)
        } else {
            return CTLineGetOffsetForStringIndex(lineFragment.line, highlightedRange.range.upperBound, nil)
        }
    }

    private func shouldHighlightLineEnding(for highlightedRangeFragment: HighlightedRangeFragment) -> Bool {
        guard highlightedRangeFragment.range.upperBound == lineFragment.range.upperBound else {
            return false
        }
        guard let lastCharacter = stringProvider.string?.last else {
            return false
        }
        return lastCharacter.isLineBreak
    }
}
