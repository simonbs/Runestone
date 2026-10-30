import Foundation

enum ContentSizeGeometry {
    enum WidthMode {
        case wrapped
        case unwrapped(longestLineWidth: CGFloat?, gutterWidth: CGFloat, lineBreakSymbolWidth: CGFloat)
    }

    static func width(scrollViewWidth: CGFloat, safeAreaInset: TextInsets,
                      textContainerInset: TextInsets, mode: WidthMode) -> CGFloat {
        let minimumWidth = scrollViewWidth - safeAreaInset.left - safeAreaInset.right
        switch mode {
        case .wrapped:
            return minimumWidth
        case let .unwrapped(longestLineWidth, gutterWidth, lineBreakSymbolWidth):
            let textContentWidth = longestLineWidth ?? scrollViewWidth
            let preferredWidth = ceil(textContentWidth + gutterWidth + textContainerInset.left
                                      + textContainerInset.right + lineBreakSymbolWidth)
            return max(preferredWidth, minimumWidth)
        }
    }

    static func height(totalLinesHeight: CGFloat, textContainerInset: TextInsets) -> CGFloat {
        ceil(totalLinesHeight + textContainerInset.top + textContainerInset.bottom)
    }
}
