import Byte
import TreeSitterLib

public final class TreeSitterNode {
    public var id: UnsafeRawPointer {
        rawValue.id
    }
    public var expressionString: String? {
        if let str = ts_node_string(rawValue) {
            let result = String(cString: str)
            str.deallocate()
            return result
        } else {
            return nil
        }
    }
    public var type: String? {
        if let str = ts_node_type(rawValue) {
            return String(cString: str)
        } else {
            return nil
        }
    }
    public var startByte: ByteCount {
        ByteCount(ts_node_start_byte(rawValue))
    }
    public var endByte: ByteCount {
        ByteCount(ts_node_end_byte(rawValue))
    }
    public var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(ts_node_start_point(rawValue))
    }
    public var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(ts_node_end_point(rawValue))
    }
    public var byteRange: ByteRange {
        ByteRange(from: startByte, to: endByte)
    }
    public var parent: TreeSitterNode? {
        getRelationship(using: ts_node_parent)
    }
    public var previousSibling: TreeSitterNode? {
        getRelationship(using: ts_node_prev_sibling)
    }
    public var nextSibling: TreeSitterNode? {
        getRelationship(using: ts_node_next_sibling)
    }
    public var textRange: TreeSitterTextRange {
        TreeSitterTextRange(startPoint: startPoint, endPoint: endPoint, startByte: startByte, endByte: endByte)
    }
    public var childCount: Int {
        Int(ts_node_child_count(rawValue))
    }

    let rawValue: TSNode

    init(node: TSNode) {
        self.rawValue = node
    }

    public func descendantForRange(from startPoint: TreeSitterTextPoint, to endPoint: TreeSitterTextPoint) -> TreeSitterNode {
        let node = ts_node_descendant_for_point_range(rawValue, startPoint.rawValue, endPoint.rawValue)
        return Self(node: node)
    }

    public func child(at index: Int) -> TreeSitterNode? {
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
    public static func == (lhs: TreeSitterNode, rhs: TreeSitterNode) -> Bool {
        lhs.rawValue.id == rhs.rawValue.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue.id)
    }
}

extension TreeSitterNode: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterNode startByte=\(startByte) endByte=\(endByte) startPoint=\(startPoint) endPoint=\(endPoint)]"
    }
}
