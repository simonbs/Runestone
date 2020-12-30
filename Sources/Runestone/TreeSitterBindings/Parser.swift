//
//  Parser.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

protocol ParserDelegate: AnyObject {
    func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String?
}

final class Parser {
    weak var delegate: ParserDelegate?
    var language: Language? {
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
    var canParse: Bool {
        return language != nil
    }
    private(set) var latestTree: Tree?

    private let encoding: SourceEncoding
    private var parser: OpaquePointer

    init(encoding: SourceEncoding) {
        self.encoding = encoding
        self.parser = ts_parser_new()
    }

    deinit {
        ts_parser_delete(parser)
    }

    func reset() {
        latestTree = nil
    }

    func parse(_ string: String) {
        let newTreePointer = string.withCString { stringPointer in
            return ts_parser_parse_string(parser, latestTree?.pointer, stringPointer, UInt32(string.count))
        }
        if let newTreePointer = newTreePointer {
            latestTree = Tree(newTreePointer)
        }
    }

    func parse() {
        let input = SourceInput(encoding: encoding) { [weak self] byteIndex, point in
            guard let self = self, let str = self.delegate?.parser(self, substringAtByteIndex: byteIndex, point: point) else {
                return []
            }
            guard let cStr = str.cString(using: self.encoding.swiftEncoding) else {
                return []
            }
            // Remove null determinator when there's more than a single character.
            if cStr.count > 1 && cStr.last == 0 {
                return cStr.dropLast()
            } else {
                return cStr
            }
        }
        let newTreePointer = ts_parser_parse(parser, latestTree?.pointer, input.rawInput)
        input.deallocate()
        if let newTreePointer = newTreePointer {
            latestTree = Tree(newTreePointer)
        }
    }

    @discardableResult
    func apply(_ inputEdit: InputEdit) -> Bool {
        if let latestTree = latestTree {
            latestTree.apply(inputEdit)
            return true
        } else {
            return false
        }
    }
}
