//
//  Node.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

public final class Node {
    let rawValue: TSNode
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
    public var startByte: uint {
        return ts_node_start_byte(rawValue)
    }
    public var endByte: uint {
        return ts_node_end_byte(rawValue)
    }
    public var isNull: Bool {
        return ts_node_is_null(rawValue)
    }
    public var isNamed: Bool {
        return ts_node_is_named(rawValue)
    }
    public var isExtra: Bool {
        return ts_node_is_extra(rawValue)
    }
    public var isMissing: Bool {
        return ts_node_is_missing(rawValue)
    }
    public var hasError: Bool {
        return ts_node_has_error(rawValue)
    }
    public var childCount: uint {
        return ts_node_child_count(rawValue)
    }

    init(node: TSNode) {
        self.rawValue = node
    }

    public func namedDescendantInRange(from startOffset: uint, to endOffset: uint) -> Node {
        let descendantRawValue = ts_node_named_descendant_for_byte_range(rawValue, startOffset, endOffset)
        return Node(node: descendantRawValue)
    }

    public func namedDescendantInRange(from startPoint: SourcePoint, to endPoint: SourcePoint) -> Node {
        let descendantRawValue = ts_node_named_descendant_for_point_range(rawValue, startPoint.rawValue, endPoint.rawValue)
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
