import _RunestoneStringUtilities
import TreeSitter

package struct TreeSitterTextPoint {
    package let rawValue: TSPoint
    package var row: UInt32 {
        rawValue.row
    }
    package var column: UInt32 {
        rawValue.column
    }

    package init(_ point: TSPoint) {
        self.rawValue = point
    }

    package init(row: UInt32, column: UInt32) {
        self.rawValue = TSPoint(row: row, column: column)
    }
}

extension TreeSitterTextPoint: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterTextPoint row=\(row) column=\(column)]"
    }
}
