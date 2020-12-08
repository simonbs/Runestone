//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

@objc public final class Parser: NSObject {
   @objc public var language: Language? {
        didSet {
            if language !== oldValue {
                if let language = language {
                    ts_parser_set_language(parser, language.pointer)
                } else {
                    ts_parser_set_language(parser, nil)
                }
            }
        }
    }

    private var parser: OpaquePointer
    private var oldTree: Tree?

    public override init() {
        parser = ts_parser_new()
        super.init()
    }

    deinit {
        ts_parser_delete(parser)
    }

    @objc public func parse(_ string: String) {
        let newTreePointer = ts_parser_parse_string(parser, nil, string, CUnsignedInt(string.utf8.count))
//        let sourceInput = SourceInput()
//        let newTreePointer = ts_parser_parse(parser, oldTree?.pointer, TSInputEncodingUTF8)

//        let inputEdit = TSInputEdit(
//            start_byte: 0,
//            old_end_byte: 0,
//            new_end_byte: 0,
//            start_point: TSPoint(row: 0, column: 0),
//            old_end_point: TSPoint(row: 0, column: 0),
//            new_end_point: TSPoint(row: 0, column: 0))
        if let newTreePointer = newTreePointer {
            let newTree = Tree(newTreePointer)
            oldTree = newTree
            walk(newTree.rootNode, in: newTree)
        }
    }
}

private extension Parser {
    private func walk(_ node: Node, in tree: Tree) {
//        let cursor = TreeCursor(tree: tree, node: node)
//        print(cursor.currentNode.type)
//        cursor.gotoFirstChild()
//        walk(cursor.currentNode, in: tree)
//        print(cursor.currentNode.type)
//        while cursor.gotoNextSibling() {
//            print(cursor.currentNode.type)
//            walk(cursor.currentNode, in: tree)
//        }
    }
}
