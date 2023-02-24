import Byte
import TreeSitterLib

public struct TreeSitterTextRange {
    public var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(row: rawValue.start_point.row, column: rawValue.start_point.column)
    }
    public var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(row: rawValue.end_point.row, column: rawValue.end_point.column)
    }
    public var startByte: ByteCount {
        ByteCount(rawValue.start_byte)
    }
    public var endByte: ByteCount {
        ByteCount(rawValue.end_byte)
    }

    let rawValue: TSRange

    init(startPoint: TreeSitterTextPoint, endPoint: TreeSitterTextPoint, startByte: ByteCount, endByte: ByteCount) {
        self.rawValue = TSRange(
            start_point: startPoint.rawValue,
            end_point: endPoint.rawValue,
            start_byte: UInt32(startByte.value),
            end_byte: UInt32(endByte.value)
        )
    }
}

extension TreeSitterTextRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterTextRange startByte=\(startByte) endByte=\(endByte) startPoint=\(startPoint) endPoint=\(endPoint)]"
    }
}
