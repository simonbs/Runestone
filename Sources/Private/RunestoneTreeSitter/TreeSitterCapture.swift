import _RunestoneStringUtilities
import Foundation

package final class TreeSitterCapture {
    package let node: TreeSitterNode
    package let index: UInt32
    package let name: String
    package let byteRange: ByteRange
    package let properties: [String: String]
    package let textPredicates: [TreeSitterTextPredicate]
    package let nameComponentCount: Int

    package convenience init(
        node: TreeSitterNode,
        index: UInt32,
        name: String,
        predicates: [TreeSitterPredicate]
    ) {
        self.init(node: node, index: index, name: name, byteRange: node.byteRange, predicates: predicates)
    }

    private init(
        node: TreeSitterNode,
        index: UInt32, 
        name: String,
        byteRange: ByteRange,
        predicates: [TreeSitterPredicate]
    ) {
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
    package var debugDescription: String {
        "[TreeSitterCapture byteRange=\(byteRange) name=\(name) properties=\(properties) textPredicates=\(textPredicates)]"
    }
}
