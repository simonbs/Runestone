import _RunestoneStringUtilities
import TreeSitter

package struct TreeSitterTextRange {
    package let rawValue: TSRange
    package var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(
            row: rawValue.start_point.row,
            column: rawValue.start_point.column
        )
    }
    package var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(
            row: rawValue.end_point.row,
            column: rawValue.end_point.column
        )
    }
    package var startByte: ByteCount {
        ByteCount(rawValue.start_byte)
    }
    package var endByte: ByteCount {
        ByteCount(rawValue.end_byte)
    }

    package init(
        startPoint: TreeSitterTextPoint,
        endPoint: TreeSitterTextPoint,
        startByte: ByteCount,
        endByte: ByteCount
    ) {
        self.rawValue = TSRange(
            start_point: startPoint.rawValue,
            end_point: endPoint.rawValue,
            start_byte: UInt32(startByte.value),
            end_byte: UInt32(endByte.value)
        )
    }
}

extension TreeSitterTextRange: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterTextRange"
        + " startByte=\(startByte)"
        + " endByte=\(endByte)"
        + " startPoint=\(startPoint)"
        + " endPoint=\(endPoint)"
        + "]"
    }
}
