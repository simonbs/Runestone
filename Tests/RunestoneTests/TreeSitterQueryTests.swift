@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

final class TreeSitterQueryTests: XCTestCase {
    func testCancellationDuringQueryDiscardsPartialCapturesAndStopsIteration() throws {
        let text = String(repeating: "let target = 42; ", count: 100) as NSString
        let query = try TreeSitterQuery(
            source: "((identifier) @variable (#eq? @variable \"target\")) (number) @number",
            language: tree_sitter_javascript())
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.language = tree_sitter_javascript()
        let tree = try XCTUnwrap(parser.parse(text))
        let stringView = StringView(string: text as String)
        let cursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        cursor.execute()
        var checks = 0
        let captures = cursor.validCaptures(in: stringView) {
            checks += 1
            return checks >= 10
        }
        XCTAssertTrue(captures.isEmpty, "Canceled queries must not publish a partial style set.")
        XCTAssertLessThan(checks, 20, "Cancellation must stop iteration instead of traversing the remaining matches.")

        let revisit = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        revisit.execute()
        XCTAssertEqual(revisit.validCaptures(in: stringView).count, 200)
    }

    func testHighlightSnapshotRetainsTreeAndPredicateTextAfterSourceReplacement() throws {
        let text = "let café = 42;" as NSString
        let query = try TreeSitterQuery(
            source: "((identifier) @variable (#eq? @variable \"café\")) (number) @number",
            language: tree_sitter_javascript())
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.language = tree_sitter_javascript()
        var tree = try XCTUnwrap(parser.parse(text))
        let snapshot = TreeSitterHighlightSnapshot(
            layers: [.init(tree: tree.copy(), query: query)], stringView: StringView(string: text as String))
        tree.apply(TreeSitterInputEdit(
                    startByte: ByteCount(0), oldEndByte: ByteCount(0), newEndByte: ByteCount(2),
                    startPoint: TreeSitterTextPoint(row: 0, column: 0),
                    oldEndPoint: TreeSitterTextPoint(row: 0, column: 0),
                    newEndPoint: TreeSitterTextPoint(row: 0, column: 2)))
        tree = try XCTUnwrap(parser.parse("let other = false;" as NSString))

        let captures = snapshot.captures(in: ByteRange(utf16Range: NSRange(location: 0, length: text.length)))
        XCTAssertEqual(captures.map(\.name), ["variable", "number"])
        XCTAssertEqual(captures.map(\.byteRange), ["café", "42"].map { ByteRange(utf16Range: text.range(of: $0)) })
        XCTAssertTrue(snapshot.captures(in: tree.rootNode.byteRange) { true }.isEmpty)
    }

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
