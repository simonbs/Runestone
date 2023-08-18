import TreeSitter

struct TreeSitterTextPoint {
    let rawValue: TSPoint
    var row: UInt32 {
        rawValue.row
    }
    var column: UInt32 {
        rawValue.column
    }

    init(_ point: TSPoint) {
        self.rawValue = point
    }

    init(row: UInt32, column: UInt32) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension TreeSitterTextPoint: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterTextPoint row=\(row) column=\(column)]"
    }
}
