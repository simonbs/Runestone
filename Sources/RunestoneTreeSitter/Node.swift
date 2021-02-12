//
//  Node.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter
import RunestoneUtils

public final class Node {
    let rawValue: TSNode
    var expressionString: String? {
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
    var startByte: ByteCount {
        return ByteCount(ts_node_start_byte(rawValue))
    }
    var endByte: ByteCount {
        return ByteCount(ts_node_end_byte(rawValue))
    }
    var isNull: Bool {
        return ts_node_is_null(rawValue)
    }
    var isNamed: Bool {
        return ts_node_is_named(rawValue)
    }
    var isExtra: Bool {
        return ts_node_is_extra(rawValue)
    }
    var isMissing: Bool {
        return ts_node_is_missing(rawValue)
    }
    var hasError: Bool {
        return ts_node_has_error(rawValue)
    }
    var childCount: uint {
        return ts_node_child_count(rawValue)
    }

    init(node: TSNode) {
        self.rawValue = node
    }

    public func namedDescendant(in byteRange: ByteRange) -> Node {
        let startOffset = UInt32(byteRange.location.value)
        let endOffset = UInt32((byteRange.location + byteRange.length).value)
        let descendantRawValue = ts_node_named_descendant_for_byte_range(rawValue, startOffset, endOffset)
        return Node(node: descendantRawValue)
    }
}

extension Node: Hashable {
    public static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.rawValue.id == rhs.rawValue.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue.id)
    }
}
