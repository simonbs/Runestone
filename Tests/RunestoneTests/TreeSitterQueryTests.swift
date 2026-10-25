@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

final class TreeSitterQueryTests: XCTestCase {
    func testQueryWithUnicodePredicateCapturesMatchingIdentifierAndTrailingPattern() throws {
        for identifier in ["café", "cafe\u{301}"] {
            let string = "let \(identifier) = 42; let ignored = 7;" as NSString
            let query = try TreeSitterQuery(
                source: """
                ((identifier) @variable (#eq? @variable "\(identifier)"))
                (number) @number
                """,
                language: tree_sitter_javascript())
            let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
            parser.language = tree_sitter_javascript()
            let tree = try XCTUnwrap(parser.parse(string))
            XCTAssertFalse(ts_node_has_error(tree.rootNode.rawValue))

            let cursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
            cursor.execute()
            let captures = cursor.validCaptures(in: StringView(string: string as String))
            XCTAssertEqual(captures.map(\.name), ["variable", "number", "number"])
            let expectedRanges = [identifier, "42", "7"].map { ByteRange(utf16Range: string.range(of: $0)) }
            XCTAssertEqual(captures.map(\.byteRange), expectedRanges)
        }
    }
}
