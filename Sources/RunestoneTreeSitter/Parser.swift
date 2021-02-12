//
//  Parser.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter
import RunestoneUtils

public protocol ParserDelegate: AnyObject {
    func parser(_ parser: Parser, bytesAt byteIndex: ByteCount) -> [Int8]?
}

public final class Parser {
    public weak var delegate: ParserDelegate?
    public let encoding: TextEncoding
    public var language: UnsafePointer<TSLanguage>? {
        didSet {
            ts_parser_set_language(parser, language)
        }
    }
    public var canParse: Bool {
        return language != nil
    }
    public private(set) var latestTree: Tree?

    private var parser: OpaquePointer

    public init(encoding: TextEncoding) {
        self.encoding = encoding
        self.parser = ts_parser_new()
    }

    deinit {
        ts_parser_delete(parser)
    }

    public func reset() {
        latestTree = nil
    }

    public func parse(_ string: String) {
        let byteCount = UInt32(string.byteCount.value)
        let newTreePointer = string.withCString { stringPointer in
            return ts_parser_parse_string(parser, latestTree?.pointer, stringPointer, byteCount)
        }
        if let newTreePointer = newTreePointer {
            latestTree = Tree(newTreePointer)
        }
    }

    public func parse() {
        let input = TextInput(encoding: encoding) { [weak self] byteIndex, _ in
            if let self = self, let bytes = self.delegate?.parser(self, bytesAt: byteIndex) {
                return bytes
            } else {
                return []
            }
        }
        let newTreePointer = ts_parser_parse(parser, latestTree?.pointer, input.rawInput)
        input.deallocate()
        if let newTreePointer = newTreePointer {
            latestTree = Tree(newTreePointer)
        }
    }

    @discardableResult
    public func apply(_ inputEdit: InputEdit) -> Bool {
        if let latestTree = latestTree {
            latestTree.apply(inputEdit)
            return true
        } else {
            return false
        }
    }
}
