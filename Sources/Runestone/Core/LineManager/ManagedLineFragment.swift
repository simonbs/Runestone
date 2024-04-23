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
    var height: CGFloat {
        scaledSize.height
    }
    var nodeTotalHeight: CGFloat = 0
    let line: CTLine

    init() {
        let attributedString = CFAttributedStringCreate(kCFAllocatorDefault, "" as NSString, [:] as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributedString)
        self.init(
            index: 0,
            range: NSRange(location: 0, length: 0),
            hiddenLength: 0,
            descent: 0,
            baseSize: .zero,
            scaledSize: .zero,
            yPosition: 0,
            line: line
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
        line: CTLine
    ) {
        self.index = index
        self.range = range
        self.hiddenLength = hiddenLength
        self.descent = descent
        self.baseSize = baseSize
        self.scaledSize = scaledSize
        self.yPosition = yPosition
        self.line = line
    }

    func insertionPointRange(forLineLocalRange lineLocalRange: NSRange) -> NSRange? {
        nil
    }
}

extension ManagedLineFragment: YOffsetRedBlackTreeNodeByOffsetQuerable {}

extension ManagedLineFragment: NodeTotalHeightRedBlackTreeChildrenUpdatable {}
