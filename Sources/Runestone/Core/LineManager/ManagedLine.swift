import _RunestoneRedBlackTree
import CoreText
import Foundation

final class ManagedLine<StringViewType: StringView>: Line {
    typealias LineFragmentType = ManagedLineFragment

    let id: LineID = UUID()
    weak var node: RedBlackTreeNode<Int, ManagedLine>?
    var index: Int {
        node!.index
    }
    var location: Int {
        node!.offset
    }
    var totalLength = 0
    var length: Int {
        totalLength - delimiterLength
    }
    var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    var yPosition: CGFloat {
        let query = YPositionFromLineNodeQuery(targetNode: node!)
        let querier = OffsetFromRedBlackTreeNodeQuerier(querying: node!.tree)
        return querier.offset(for: query)!
    }
    private(set) var width: CGFloat = 0
    var height: CGFloat {
        guard lineFragmentManager.numberOfLineFragments > 0 else {
            return estimatedHeight
        }
        let lineFragmentIndex = lineFragmentManager.numberOfLineFragments - 1
        let lineFragment = lineFragmentManager.lineFragment(atIndex: lineFragmentIndex)
        return lineFragment.yPosition + lineFragment.scaledSize.height
    }
    var nodeTotalHeight: CGFloat = 0
    var numberOfLineFragments: Int {
        lineFragmentManager.numberOfLineFragments
    }

    private let estimatedHeight: CGFloat
    private let typesetter: LineTypesetter<StringViewType, ManagedLine<StringViewType>>
    private var lineFragmentManager = LineFragmentManager()

    init(typesetter: LineTypesetter<StringViewType, ManagedLine<StringViewType>>, estimatedHeight: CGFloat) {
        self.typesetter = typesetter
        self.estimatedHeight = estimatedHeight
    }

    func location(closestTo lineLocalPoint: CGPoint) -> Int {
        guard let closestLineFragment = lineFragmentManager.lineFragment(atYOffset: lineLocalPoint.y) else {
            return location
        }
        let lineFragmentLocalPoint = CGPoint(x: lineLocalPoint.x, y: lineLocalPoint.y - closestLineFragment.yPosition)
        let localLocation = CTLineGetStringIndexForPosition(closestLineFragment.line, lineFragmentLocalPoint)
        return location + min(localLocation, length)
    }

    func invalidateTypesetText() {
        width = 0
        lineFragmentManager.reset()
        typesetter.invalidate()
    }

    func typesetText(toLocation location: Int) {
        let lineFragments = typesetter.typesetText(toLocation: location)
        handleTypesetLineFragments(lineFragments)
    }

    func typesetText(toYOffset yOffset: CGFloat) {
        let lineFragments = typesetter.typesetText(toYOffset: yOffset)
        handleTypesetLineFragments(lineFragments)
    }

    func lineFragment(containingLocation location: Int) -> ManagedLineFragment {
        lineFragmentManager.lineFragment(containingLocation: location)
    }

    func lineFragment(atIndex index: Int) -> ManagedLineFragment {
        lineFragmentManager.lineFragment(atIndex: index)
    }

    func lineFragments(in rect: CGRect) -> [ManagedLineFragment] {
        let localYPosition = yPosition
        let localMinY = rect.minY - localYPosition
        let localMaxY = rect.maxY - localYPosition
        return lineFragmentManager.lineFragments(withYOffsetIn: localMinY ... localMaxY)
    }
}

private extension ManagedLine {
    private func handleTypesetLineFragments(_ lineFragments: [TypesetLineFragment]) {
        lineFragmentManager.addTypesetLineFragments(lineFragments, belongingToLineWithId: id)
        // Update total line height.
        node!.tree.updateAfterChangingChildren(of: node!)
        if let maxLineFragment = lineFragments.max(by: { $0.scaledSize.width < $1.scaledSize.width }) {
            width = max(width, maxLineFragment.scaledSize.width)
        }
    }
}

extension ManagedLine: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ManagedLine, rhs: ManagedLine) -> Bool {
        lhs.id == rhs.id
    }
}

extension ManagedLine: YOffsetRedBlackTreeNodeByOffsetQuerable {}

extension ManagedLine: NodeTotalHeightRedBlackTreeChildrenUpdatable {}