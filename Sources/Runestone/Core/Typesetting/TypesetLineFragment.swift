import CoreText
import Foundation

struct TypesetLineFragment {
    let line: CTLine
    let index: Int
    let range: NSRange
    let visibleRange: NSRange
    let hiddenLength: Int
    let descent: CGFloat
    let baseSize: CGSize
    let scaledSize: CGSize
    let yPosition: CGFloat

    init(
        line: CTLine,
        index: Int,
        visibleRange: NSRange,
        hiddenLength: Int = 0,
        yPosition: CGFloat,
        heightMultiplier: CGFloat
    ) {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let baseSize = CGSize(width: width, height: ascent + descent + leading)
        let scaledSize = CGSize(width: baseSize.width, height: baseSize.height * heightMultiplier)
        self.init(
            line: line,
            index: index,
            visibleRange: visibleRange,
            hiddenLength: hiddenLength,
            descent: descent,
            baseSize: baseSize,
            scaledSize: scaledSize,
            yPosition: yPosition
        )
    }

    private init(
        line: CTLine,
        index: Int,
        visibleRange: NSRange,
        hiddenLength: Int = 0,
        descent: CGFloat,
        baseSize: CGSize,
        scaledSize: CGSize,
        yPosition: CGFloat
    ) {
        self.line = line
        self.index = index
        self.visibleRange = visibleRange
        self.hiddenLength = hiddenLength
        self.range = NSRange(location: visibleRange.location, length: visibleRange.length + hiddenLength)
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
    }

    func withHiddenLength(_ hiddenLength: Int) -> Self {
        Self(
            line: line,
            index: index,
            visibleRange: visibleRange,
            hiddenLength: hiddenLength,
            descent: descent,
            baseSize: baseSize,
            scaledSize: scaledSize,
            yPosition: yPosition
        )
    }
}
