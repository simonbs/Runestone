//
//  Tree.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

final class Tree {
    let pointer: OpaquePointer
    var rootNode: Node {
        return Node(node: ts_tree_root_node(pointer))
    }

    init(_ tree: OpaquePointer) {
        self.pointer = tree
    }

    deinit {
        ts_tree_delete(pointer)
    }

    func apply(_ inputEdit: InputEdit) {
        withUnsafePointer(to: inputEdit.asRawInputEdit()) { inputEditPointer in
            ts_tree_edit(pointer, inputEditPointer)
        }
    }

    func rangesChanged(comparingTo otherTree: Tree) -> [TextRange] {
        var count = CUnsignedInt(0)
        let ptr = ts_tree_get_changed_ranges(pointer, otherTree.pointer, &count)
        return UnsafeBufferPointer(start: ptr, count: Int(count)).map {
            let startPoint = TextPoint($0.start_point)
            let endPoint = TextPoint($0.end_point)
            return TextRange(
                startPoint: startPoint,
                endPoint: endPoint,
                startByte: ByteCount($0.start_byte),
                endByte: ByteCount($0.end_byte))
        }
    }
}
