import CoreGraphics
import Foundation

final class ManagedLine: Line {
    typealias LineFragmentType = ManagedLineFragment

    let id: LineID = UUID()
    let index: Int = 0
    let location: Int = 0
    var totalLength = 0
    var length: Int {
        totalLength - delimiterLength
    }
    var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    let yPosition: CGFloat = 0
    var height: CGFloat
    var totalHeight: CGFloat = 0
    let numberOfLineFragments: Int = 0
    let lineFragments: [LineFragmentType] = []

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

    init(height: CGFloat) {
        self.height = height
    }

    func location(closestTo localPoint: CGPoint) -> Int {
        0
    }

    func lineFragment(containingCharacterAt location: Int) -> ManagedLineFragment {
        fatalError()
    }

    func lineFragment(atIndex index: Int) -> ManagedLineFragment {
        fatalError()
    }
}

extension ManagedLine: Equatable {
    static func == (lhs: ManagedLine, rhs: ManagedLine) -> Bool {
        lhs.id == rhs.id
    }
}
