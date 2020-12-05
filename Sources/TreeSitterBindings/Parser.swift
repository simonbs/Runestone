//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

public final class Parser {
    private var parser: OpaquePointer

    public init() {
        parser = ts_parser_new()
    }

    deinit {
        ts_parser_delete(parser)
    }
}
