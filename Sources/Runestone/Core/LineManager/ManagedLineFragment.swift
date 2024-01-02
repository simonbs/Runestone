import CoreText
import Foundation

struct ManagedLineFragment: LineFragment {
    let id: LineFragmentID = UUID()
    let index: Int
    let range: NSRange
    let hiddenLength: Int
    let descent: CGFloat
    let baseSize: CGSize
    let scaledSize: CGSize
    let yPosition: CGFloat
    var totalHeight: CGFloat = 0
    var line: CTLine {
        _line!
    }

    private var _line: CTLine?

    init() {
        self.init(
            index: 0,
            range: NSRange(location: 0, length: 0),
            hiddenLength: 0,
            descent: 0,
            baseSize: .zero,
            scaledSize: .zero,
            yPosition: 0,
            line: nil
        )
    }

    init(_ typesetLineFragment: TypesetLineFragment) {
        self.init(
            index: typesetLineFragment.index,
            range: typesetLineFragment.range,
            hiddenLength: typesetLineFragment.hiddenLength,
            descent: typesetLineFragment.descent,
            baseSize: typesetLineFragment.baseSize,
            scaledSize: typesetLineFragment.scaledSize,
            yPosition: typesetLineFragment.yPosition,
            line: typesetLineFragment.line
        )
    }

    private init(
        index: Int,
        range: NSRange,
        hiddenLength: Int,
        descent: CGFloat,
        baseSize: CGSize,
        scaledSize: CGSize,
        yPosition: CGFloat,
        line: CTLine?
    ) {
        self.index = index
        self.range = range
        self.hiddenLength = hiddenLength
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
        self._line = line
    }

    func insertionPointRange(forLineLocalRange lineLocalRange: NSRange) -> NSRange? {
        nil
    }
}
