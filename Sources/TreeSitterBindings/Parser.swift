//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

public final class Parser {
    public var language: Language? {
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

    public init() {
        parser = ts_parser_new()
    }

    deinit {
        ts_parser_delete(parser)
    }

    public func parse(_ string: String) {
//        let treePointer = ts_parser_parse_string(parser, nil, string, CUnsignedInt(string.utf8.count))
        let sourceInput = SourceInput()

        let newTreePointer = ts_parser_parse(parser, oldTree?.pointer, TSInputEncodingUTF8)
        if let newTreePointer = newTreePointer {
            let newTree = Tree(newTreePointer)
            print(newTree.rootNode.expressionString)
            oldTree = newTree
        }
    }
}
