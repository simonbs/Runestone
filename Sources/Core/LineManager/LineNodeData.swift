import Byte
import CoreGraphics
import Foundation

public final class LineNodeData {
    public var delimiterLength = 0 {
        didSet {
            assert(delimiterLength >= 0 && delimiterLength <= 2)
        }
    }
    public var totalLength = 0
    public var length: Int {
        totalLength - delimiterLength
    }
    public var lineHeight: CGFloat
    public var totalLineHeight: CGFloat = 0
    public var nodeTotalByteCount = ByteCount(0)
    public var startByte: ByteCount {
        node!.tree.startByte(of: node!)
    }
    public var byteCount = ByteCount(0)
    public var byteRange: ByteRange {
        ByteRange(location: startByte, length: byteCount - ByteCount(delimiterLength))
    }
    public var totalByteRange: ByteRange {
        ByteRange(location: startByte, length: byteCount)
    }

    weak var node: LineNode?

    init(lineHeight: CGFloat) {
        self.lineHeight = lineHeight
    }
}

private extension LineTree {
    func startByte(of node: Node) -> ByteCount {
        offset(of: node, valueKeyPath: \.data.byteCount, totalValueKeyPath: \.data.nodeTotalByteCount, minimumValue: ByteCount(0))
    }
}

extension LineNodeData: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[LineNodeData length=\(length) delimiterLength=\(delimiterLength) totalLength=\(totalLength)]"
    }
}
