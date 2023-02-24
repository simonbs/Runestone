import Byte
import Foundation

public final class TreeSitterCapture {
    public let node: TreeSitterNode
    public let index: UInt32
    public let name: String
    public let byteRange: ByteRange
    public let properties: [String: String]
    public let textPredicates: [TreeSitterTextPredicate]
    public let nameComponentCount: Int

    public convenience init(node: TreeSitterNode, index: UInt32, name: String, predicates: [TreeSitterPredicate]) {
        self.init(node: node, index: index, name: name, byteRange: node.byteRange, predicates: predicates)
    }

    private init(node: TreeSitterNode, index: UInt32, name: String, byteRange: ByteRange, predicates: [TreeSitterPredicate]) {
        let predicateMapResult = TreeSitterPredicateMapper.map(predicates)
        self.node = node
        self.index = index
        self.name = name
        self.byteRange = byteRange
        self.properties = predicateMapResult.properties
        self.textPredicates = predicateMapResult.textPredicates
        self.nameComponentCount = name.split(separator: ".").count
    }
}

extension TreeSitterCapture: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterCapture byteRange=\(byteRange) name=\(name) properties=\(properties) textPredicates=\(textPredicates)]"
    }
}
