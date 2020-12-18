//
//  Parser.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

@objc public protocol ParserDelegate: AnyObject {
    func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String?
}

@objc public final class Parser: NSObject {
    @objc public weak var delegate: ParserDelegate?
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

    private let encoding: SourceEncoding
    private var parser: OpaquePointer
    private var oldTree: Tree?
    private var query: Query?

    @objc public init(encoding: SourceEncoding) {
        self.encoding = encoding
        self.parser = ts_parser_new()
        super.init()
    }

    deinit {
        ts_parser_delete(parser)
    }

    @objc public func parse(_ string: String) {
        let newTreePointer = string.withCString { stringPointer in
            return ts_parser_parse_string(parser, oldTree?.pointer, stringPointer, UInt32(string.count))
        }
        if let newTreePointer = newTreePointer {
            let newTree = Tree(newTreePointer)
            oldTree = newTree
        }
    }

    @objc public func parse() {
        let input = SourceInput(encoding: encoding) { [weak self] byteIndex, point in
            if let self = self {
                let str = self.delegate?.parser(self, substringAtByteIndex: byteIndex, point: point)
                let asd: [Int8]? = str?.cString(using: self.encoding.swiftEncoding)?.dropLast()
                return asd ?? []
            } else {
                return nil
            }
        }
        let newTreePointer = ts_parser_parse(parser, oldTree?.pointer, input.rawInput)
        input.deallocate()
        if let newTreePointer = newTreePointer {
            let newTree = Tree(newTreePointer)
            oldTree = newTree
        }
    }

    @objc(applyEdit:)
    public func apply(_ inputEdit: InputEdit) {
        oldTree?.apply(inputEdit)
    }

    @objc(runQueryFromLocation:toLocation:)
    public func runQuery(from start: UInt32, to end: UInt32) {
        let highlightsFileURL = Bundle.module.url(forResource: "highlights", withExtension: "scm", subdirectory: "queries/javascript")!
        let source = try! String(contentsOf: highlightsFileURL)
        let queryResult = Query.create(fromSource: source, in: language!)
        switch queryResult {
        case .success(let query):
            if let tree = oldTree {
                let iter = QueryCaptureIterator(query: query, node: tree.rootNode)
                iter.execute()
                iter.setQueryRange(from: start, to: end)
                while let capture = iter.next() {
                    print(capture.name)
                }
            }
        case .failure(let error):
            print(error)
        }
    }
}
