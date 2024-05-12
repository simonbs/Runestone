import _RunestoneMultiPlatform
import CoreText
import Foundation

struct HighlightedRangeLineFragmentRenderer<
    StringViewType: StringView,
    LineType: Line
>: LineFragmentRendering {
    let stringView: StringViewType
    let highlightedRangeFragments: [HighlightedRangeFragment]

    func render(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        guard !highlightedRangeFragments.isEmpty else {
            return
        }
        context.saveGState()
        for highlightedRange in highlightedRangeFragments {
            render(highlightedRange, highlighting: lineFragment, in: line, to: context)
        }
        context.restoreGState()
    }
}

private extension HighlightedRangeLineFragmentRenderer {
    private func render(
        _ highlightedRange: HighlightedRangeFragment,
        highlighting lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        let startX = CTLineGetOffsetForStringIndex(lineFragment.line, highlightedRange.range.lowerBound, nil)
        let endX = endX(for: highlightedRange, highlighting: lineFragment, in: line, context: context)
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

    private func endX(
        for highlightedRange: HighlightedRangeFragment,
        highlighting lineFragment: LineType.LineFragmentType,
        in line: LineType,
        context: CGContext
    ) -> CGFloat {
        if shouldHighlightLineEnding(for: highlightedRange, highlighting: lineFragment, in: line) {
            return CGFloat(context.width)
        } else {
            return CTLineGetOffsetForStringIndex(lineFragment.line, highlightedRange.range.upperBound, nil)
        }
    }

    private func shouldHighlightLineEnding(
        for highlightedRangeFragment: HighlightedRangeFragment,
        highlighting lineFragment: LineType.LineFragmentType,
        in line: LineType
    ) -> Bool {
        guard highlightedRangeFragment.range.upperBound == lineFragment.range.upperBound else {
            return false
        }
        let lineFragmentRange = lineFragment.visibleRange
        let lineRange = NSRange(
            location: line.location + lineFragmentRange.location,
            length: lineFragmentRange.length
        )
        guard let lastCharacter = stringView.substring(in: lineRange)?.last else {
            return false
        }
        return lastCharacter.isLineBreak
    }
}
