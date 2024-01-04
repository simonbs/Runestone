import _RunestoneRedBlackTree
import Foundation

final class ManagedLine: Line {
    typealias LineFragmentType = ManagedLineFragment

    let id: LineID = UUID()
    var index: Int {
        indexReader!.index
    }
    var location: Int {
        locationReader!.location
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
        yPositionReader!.yPosition
    }
    private(set) var height: CGFloat
    var totalHeight: CGFloat = 0 {
        didSet {
            print("Did set total height: \(totalHeight)")
        }
    }
    var numberOfLineFragments: Int {
        lineFragmentManager.numberOfLineFragments
    }
    weak var indexReader: ManagedLineIndexReading?
    weak var locationReader: ManagedLineLocationReading?
    weak var yPositionReader: ManagedLineYPositionReading?

    private let typesetter: Typesetting
    private var lineFragmentManager = LineFragmentManager()

//    var byteCount = ByteCount(0)
//    var totalByteCount = ByteCount(0)
//    var startByte: ByteCount {
//        let querier = OffsetFromRedBlackTreeNodeQuerier(querying: node!.tree)
//        let query = ByteCountFromLineNodeQuery(targetNode: node!)
//        return querier.offset(for: query)!
//    }
//    var byteRange: ByteRange {
//        ByteRange(location: startByte, length: byteCount - ByteCount(delimiterLength))
//    }
//    var totalByteRange: ByteRange {
//        ByteRange(location: startByte, length: byteCount)
//    }

    init(typesetter: Typesetting, estimatedHeight: CGFloat) {
        self.typesetter = typesetter
        self.height = estimatedHeight
    }

    func location(closestTo localPoint: CGPoint) -> Int {
        0
    }

    func invalidateTypesetText() {
        lineFragmentManager.reset()
        typesetter.invalidateTypesetText(in: self)
    }

    func typesetText(toLocation location: Int) {
        let lineFragments = typesetter.typesetText(in: self, toLocation: location)
        lineFragmentManager.addTypesetLineFragments(lineFragments)
    }

    func typesetText(toYOffset yOffset: CGFloat) {
        let lineFragments = typesetter.typesetText(in: self, toYOffset: yOffset)
        lineFragmentManager.addTypesetLineFragments(lineFragments)
    }

    func lineFragment(containingLocation location: Int) -> ManagedLineFragment {
        lineFragmentManager.lineFragment(containingLocation: location)
    }

    func lineFragment(atIndex index: Int) -> ManagedLineFragment {
        lineFragmentManager.lineFragment(atIndex: index)
    }

    func lineFragments(in rect: CGRect) -> [ManagedLineFragment] {
        lineFragmentManager.lineFragments(withYOffsetIn: rect.minY - yPosition ... rect.maxY - yPosition)
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
