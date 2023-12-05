import _RunestoneStringUtilities
import TreeSitter

package final class TreeSitterNode {
    package var id: UnsafeRawPointer {
        rawValue.id
    }
    package var expressionString: String? {
        if let str = ts_node_string(rawValue) {
            let result = String(cString: str)
            str.deallocate()
            return result
        } else {
            return nil
        }
    }
    package var type: String? {
        if let str = ts_node_type(rawValue) {
            return String(cString: str)
        } else {
            return nil
        }
    }
    package var startByte: ByteCount {
        ByteCount(ts_node_start_byte(rawValue))
    }
    package var endByte: ByteCount {
        ByteCount(ts_node_end_byte(rawValue))
    }
    package var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(ts_node_start_point(rawValue))
    }
    package var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(ts_node_end_point(rawValue))
    }
    package var byteRange: ByteRange {
        ByteRange(from: startByte, to: endByte)
    }
    package var parent: TreeSitterNode? {
        getRelationship(using: ts_node_parent)
    }
    package var previousSibling: TreeSitterNode? {
        getRelationship(using: ts_node_prev_sibling)
    }
    package var nextSibling: TreeSitterNode? {
        getRelationship(using: ts_node_next_sibling)
    }
    package var textRange: TreeSitterTextRange {
        TreeSitterTextRange(
            startPoint: startPoint,
            endPoint: endPoint,
            startByte: startByte,
            endByte: endByte
        )
    }
    package var childCount: Int {
        Int(ts_node_child_count(rawValue))
    }

    package let rawValue: TSNode

    package init(node: TSNode) {
        self.rawValue = node
    }

    package func descendantForRange(
        from startPoint: TreeSitterTextPoint,
        to endPoint: TreeSitterTextPoint
    ) -> TreeSitterNode {
        let node = ts_node_descendant_for_point_range(
            rawValue,
            startPoint.rawValue,
            endPoint.rawValue
        )
        return Self(node: node)
    }

    package func child(at index: Int) -> TreeSitterNode? {
        if index < childCount {
            let node = ts_node_child(rawValue, UInt32(index))
            return Self(node: node)
        } else {
            return nil
        }
    }
}

private extension TreeSitterNode {
    private func getRelationship(using f: (TSNode) -> TSNode) -> TreeSitterNode? {
        let node = f(rawValue)
        if ts_node_is_null(node) {
            return nil
        } else {
            return TreeSitterNode(node: node)
        }
    }
}

extension TreeSitterNode: Hashable {
    package static func == (lhs: TreeSitterNode, rhs: TreeSitterNode) -> Bool {
        lhs.rawValue.id == rhs.rawValue.id
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue.id)
    }
}

extension TreeSitterNode: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterNode"
        + " startByte=\(startByte)"
        + " endByte=\(endByte)"
        + " startPoint=\(startPoint)"
        + " endPoint=\(endPoint)"
        + "]"
    }
}
