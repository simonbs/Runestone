import Foundation

struct LineNodeID: RedBlackTreeNodeID, Hashable {
    let id = UUID()
    var rawValue: String {
        id.uuidString
    }

    init() {}
}

extension LineNodeID: CustomDebugStringConvertible {
    var debugDescription: String {
        rawValue
    }
}
