import Foundation

struct LinePosition: Hashable, Equatable {
    let row: Int
    let column: Int

    static func == (lhs: LinePosition, rhs: LinePosition) -> Bool {
        lhs.row == rhs.row && lhs.column == rhs.column
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(row)
        hasher.combine(column)
    }
}

extension LinePosition: CustomDebugStringConvertible {
    var debugDescription: String {
        "[LinePosition row=\(row) column=\(column)]"
    }
}
