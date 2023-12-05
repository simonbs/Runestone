import _RunestoneStringUtilities
import TreeSitter

package final class TreeSitterInputEdit {
    package let startByte: ByteCount
    package let oldEndByte: ByteCount
    package let newEndByte: ByteCount
    package let startPoint: TreeSitterTextPoint
    package let oldEndPoint: TreeSitterTextPoint
    package let newEndPoint: TreeSitterTextPoint

    package init(
        startByte: ByteCount,
        oldEndByte: ByteCount,
        newEndByte: ByteCount,
        startPoint: TreeSitterTextPoint,
        oldEndPoint: TreeSitterTextPoint,
        newEndPoint: TreeSitterTextPoint
    ) {
        self.startByte = startByte
        self.oldEndByte = oldEndByte
        self.newEndByte = newEndByte
        self.startPoint = startPoint
        self.oldEndPoint = oldEndPoint
        self.newEndPoint = newEndPoint
    }
}

extension TreeSitterInputEdit: CustomDebugStringConvertible {
     package var debugDescription: String {
        "[TreeSitterInputEdit"
         + " startByte=\(startByte)"
         + " oldEndByte=\(oldEndByte)"
         + " newEndByte=\(newEndByte)"
         + " startPoint=\(startPoint)"
         + " oldEndPoint=\(oldEndPoint)"
         + " newEndPoint=\(newEndPoint)"
         + "]"
    }
}

extension TSInputEdit {
    init(_ inputEdit: TreeSitterInputEdit) {
        self.init(
            start_byte: UInt32(inputEdit.startByte.value),
            old_end_byte: UInt32(inputEdit.oldEndByte.value),
            new_end_byte: UInt32(inputEdit.newEndByte.value),
            start_point: inputEdit.startPoint.rawValue,
            old_end_point: inputEdit.oldEndPoint.rawValue,
            new_end_point: inputEdit.newEndPoint.rawValue
        )
    }
}
