import Foundation
import RedBlackTree

public struct DocumentLineNodeID: RedBlackTreeNodeID, Hashable {
    public let id = UUID()
    public var rawValue: String {
        id.uuidString
    }

    public init() {}
}

extension DocumentLineNodeID: CustomDebugStringConvertible {
    public var debugDescription: String {
        rawValue
    }
}
