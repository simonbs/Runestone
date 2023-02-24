import LineManager
import TreeSitter

extension TreeSitterTextPoint {
    init(_ linePosition: LinePosition) {
        let row = UInt32(linePosition.row)
        let column = UInt32(linePosition.column * 2)
        self.init(row: row, column: column)
    }
}
