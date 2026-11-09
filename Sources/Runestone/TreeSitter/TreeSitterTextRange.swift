import TreeSitter

final class TreeSitterTextRange {
    let rawValue: TSRange
    var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(row: rawValue.start_point.row, column: rawValue.start_point.column)
    }
    var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(row: rawValue.end_point.row, column: rawValue.end_point.column)
    }
    var startByte: ByteCount {
        ByteCount(rawValue.start_byte)
    }
    var endByte: ByteCount {
        ByteCount(rawValue.end_byte)
    }

    init(startPoint: TreeSitterTextPoint, endPoint: TreeSitterTextPoint, startByte: ByteCount, endByte: ByteCount) {
        self.rawValue = TSRange(
            start_point: startPoint.rawValue,
            end_point: endPoint.rawValue,
            start_byte: UInt32(startByte.value),
            end_byte: UInt32(endByte.value))
    }
}

extension TreeSitterTextRange {
    /// An edit at either boundary can change what the injected grammar sees.
    func translatedOutsideEdit(_ edit: TreeSitterInputEdit) -> TreeSitterTextRange? {
        if edit.startByte > endByte {
            return self
        }
        guard edit.oldEndByte < startByte else {
            return nil
        }
        func translate(_ point: TreeSitterTextPoint) -> TreeSitterTextPoint {
            let row = edit.newEndPoint.row + (point.row - edit.oldEndPoint.row)
            let column = point.row == edit.oldEndPoint.row
                ? edit.newEndPoint.column + (point.column - edit.oldEndPoint.column)
                : point.column
            return TreeSitterTextPoint(row: row, column: column)
        }
        return TreeSitterTextRange(
            startPoint: translate(startPoint),
            endPoint: translate(endPoint),
            startByte: edit.newEndByte + (startByte - edit.oldEndByte),
            endByte: edit.newEndByte + (endByte - edit.oldEndByte)
        )
    }
}

extension TreeSitterTextRange: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterTextRange startByte=\(startByte) endByte=\(endByte) startPoint=\(startPoint) endPoint=\(endPoint)]"
    }
}
