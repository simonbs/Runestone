//
//  TreeSitterParser.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

protocol TreeSitterParserDelegate: AnyObject {
    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult?
}

final class TreeSitterParser {
    weak var delegate: TreeSitterParserDelegate?
    let encoding: TSInputEncoding
    var language: UnsafePointer<TSLanguage>? {
        didSet {
            ts_parser_set_language(pointer, language)
        }
    }
    var canParse: Bool {
        return language != nil
    }

    private var pointer: OpaquePointer

    init(encoding: TSInputEncoding) {
        self.encoding = encoding
        self.pointer = ts_parser_new()
    }

    deinit {
        ts_parser_delete(pointer)
    }

    func parse(_ string: NSString, oldTree: TreeSitterTree? = nil) -> TreeSitterTree? {
        guard string.length > 0 else {
            return nil
        }
        guard let stringEncoding = encoding.stringEncoding else {
            return nil
        }
        let bytesPointer = string.cString(using: stringEncoding.rawValue)
        let bytesCount = UInt32(string.byteCount.value)
        if let newTreePointer = ts_parser_parse_string_encoding(pointer, oldTree?.pointer, bytesPointer, bytesCount, encoding) {
            return TreeSitterTree(newTreePointer)
        } else {
            return nil
        }
    }

    func parse(oldTree: TreeSitterTree? = nil) -> TreeSitterTree? {
        let input = TreeSitterTextInput(encoding: encoding) { [weak self] byteIndex, _ in
            if let self = self {
                return self.delegate?.parser(self, bytesAt: byteIndex)
            } else {
                return nil
            }
        }
        let newTreePointer = ts_parser_parse(pointer, oldTree?.pointer, input.rawInput)
        input.deallocate()
        if let newTreePointer = newTreePointer {
            return TreeSitterTree(newTreePointer)
        } else {
            return nil
        }
    }

    @discardableResult
    func setIncludedRanges(_ ranges: [TreeSitterTextRange]) -> Bool {
        let rawRanges = ranges.map { $0.rawValue }
        return rawRanges.withUnsafeBufferPointer { rangesPointer in
            return ts_parser_set_included_ranges(pointer, rangesPointer.baseAddress, UInt32(rawRanges.count))
        }
    }

    func removeAllIncludedRanges() {
        ts_parser_set_included_ranges(pointer, nil, 0)
    }
}

private extension TSInputEncoding {
    var stringEncoding: String.Encoding? {
        switch self {
        case TSInputEncodingUTF8:
            return .utf8
        case TSInputEncodingUTF16:
            return String.preferredUTF16Encoding
        default:
            return nil
        }
    }
}
