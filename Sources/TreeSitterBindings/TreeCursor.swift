//
//  TreeCursor.swift
//  
//
//  Created by Simon Støvring on 06/12/2020.
//

import TreeSitter

final class TreeCursor {
    public var currentNode: Node {
        get {
            let rawNode = withUnsafePointer(to: &self.rawValue) { pointer in
                ts_tree_cursor_current_node(pointer)
            }
            return Node(node: rawNode)
        }
    }

    private let tree: Tree
    private var rawValue: TSTreeCursor

    init(tree: Tree, node: Node) {
        self.tree = tree
        self.rawValue = ts_tree_cursor_new(node.rawValue)
    }

    deinit {
        withUnsafeMutablePointer(to: &self.rawValue) { pointer in
            ts_tree_cursor_delete(pointer)
        }
    }

    func gotoFirstChild() -> Bool {
        return withUnsafeMutablePointer(to: &self.rawValue) { pointer in
            ts_tree_cursor_goto_first_child(pointer)
        }
    }

    func gotoNextSibling() -> Bool {
        return withUnsafeMutablePointer(to: &self.rawValue) { pointer in
            ts_tree_cursor_goto_next_sibling(pointer)
        }
    }
}
