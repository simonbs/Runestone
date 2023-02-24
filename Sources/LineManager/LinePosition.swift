import Foundation

public final class LinePosition: Hashable, Equatable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public static func == (lhs: LinePosition, rhs: LinePosition) -> Bool {
        lhs.row == rhs.row && lhs.column == rhs.column
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(row)
        hasher.combine(column)
    }
}

extension LinePosition: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[LinePosition row=\(row) column=\(column)]"
    }
}
