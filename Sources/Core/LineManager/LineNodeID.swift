import Foundation
import RedBlackTree

public struct LineNodeID: RedBlackTreeNodeID, Hashable {
    public let id = UUID()
    public var rawValue: String {
        id.uuidString
    }

    public init() {}
}

extension LineNodeID: CustomDebugStringConvertible {
    public var debugDescription: String {
        rawValue
    }
}
