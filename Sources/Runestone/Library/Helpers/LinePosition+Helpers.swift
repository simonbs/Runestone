import _RunestoneTreeSitter

extension LinePosition {
    init(_ point: TreeSitterTextPoint) {
        let row = Int(point.row)
        let column = Int(point.column / 2)
        self.init(row: row, column: column)
    }
}

extension TreeSitterTextPoint {
    init(_ linePosition: LinePosition) {
        let row = UInt32(linePosition.row)
        let column = UInt32(linePosition.column * 2)
        self.init(row: row, column: column)
    }
}
