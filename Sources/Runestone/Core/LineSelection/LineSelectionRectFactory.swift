import Foundation

struct LineSelectionRectFactory {
    let viewport: CGRect
    let caret: Caret
    let lineManager: LineManager
    let lineSelectionDisplayType: LineSelectionDisplayType
    let textContainerInset: MultiPlatformEdgeInsets
    let lineHeightMultiplier: CGFloat
    let selectedRange: NSRange
    var rect: CGRect? {
        switch lineSelectionDisplayType {
        case .line:
            return getEntireLineSelectionRect()
        case .lineFragment:
            return getLineFragmentSelectionRect()
        case .disabled:
            return nil
        }
    }
}

private extension LineSelectionRectFactory {
    private func getEntireLineSelectionRect() -> CGRect? {
        guard let (startLine, endLine) = lineManager.startAndEndLine(in: selectedRange) else {
            return nil
        }
        let yPosition = startLine.yPosition
        let height = (endLine.yPosition + endLine.data.lineHeight) - yPosition
        return CGRect(x: viewport.minX, y: textContainerInset.top + yPosition, width: viewport.width, height: height)
    }

    private func getLineFragmentSelectionRect() -> CGRect {
        let height = caret.frame.value.height * lineHeightMultiplier
        let minY = caret.frame.value.minY - (height - caret.frame.value.height) / 2
        return CGRect(x: viewport.minX, y: minY, width: viewport.width, height: height)
    }
}
