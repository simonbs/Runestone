import Foundation
import Runestone

enum InsertionPointShapeSetting: String, CaseIterable, Hashable {
    case verticalBar
    case underline
    case block

    var title: String {
        switch self {
        case .verticalBar:
            return "Vertical Bar"
        case .underline:
            return "Underline"
        case .block:
            return "Block"
        }
    }

    var insertionPointShape: InsertionPointShape {
        switch self {
        case .verticalBar:
            return .verticalBar
        case .underline:
            return .underline
        case .block:
            return .block
        }
    }
}
