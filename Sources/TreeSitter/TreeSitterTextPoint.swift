import TreeSitterLib

public struct TreeSitterTextPoint {
    public var row: UInt32 {
        rawValue.row
    }
    public var column: UInt32 {
        rawValue.column
    }

    let rawValue: TSPoint

    init(_ point: TSPoint) {
        self.rawValue = point
    }

    public init(row: UInt32, column: UInt32) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension TreeSitterTextPoint: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterTextPoint row=\(row) column=\(column)]"
    }
}
