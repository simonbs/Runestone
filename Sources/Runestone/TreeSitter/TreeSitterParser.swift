import Foundation
import TreeSitter

final class TreeSitterParser {
    var language: UnsafePointer<TSLanguage>? {
        didSet {
            ts_parser_set_language(pointer, language)
        }
    }

    let encoding: TSInputEncoding
    var canParse: Bool {
        language != nil
    }

    private var pointer: OpaquePointer

    init() {
        self.encoding = TSInputEncodingUTF16
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
        var usedLength = 0
        let buffer = string.getAllBytes(withEncoding: stringEncoding, usedLength: &usedLength)
        let newTreePointer = ts_parser_parse_string_encoding(pointer, oldTree?.pointer, buffer, UInt32(usedLength), encoding)
        buffer?.deallocate()
        if let newTreePointer = newTreePointer {
            return TreeSitterTree(newTreePointer)
        } else {
            return nil
        }
    }

    func parse(readingFrom reader: TreeSitterByteReader, oldTree: TreeSitterTree? = nil) -> TreeSitterTree? {
        let input = TreeSitterTextInput(encoding: encoding) { byteIndex, _ in
            reader.readBytes(startingAt: byteIndex)
        }
        let newTreePointer = ts_parser_parse(pointer, oldTree?.pointer, input.makeTSInput())
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
            ts_parser_set_included_ranges(pointer, rangesPointer.baseAddress, UInt32(rawRanges.count))
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
