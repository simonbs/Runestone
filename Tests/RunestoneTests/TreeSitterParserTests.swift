@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

final class TreeSitterParserTests: XCTestCase {
    private let delegate = MockTreeSitterParserDelegate()

    func testParseUnicodeStringInBothUTF16ByteOrders() throws {
        let string: NSString = "let café = \"Grøn 😀\";\nlet count = 42;"
        let query = try TreeSitterQuery(
            source: "(identifier) @variable (string) @string (number) @number",
            language: tree_sitter_javascript())
        for encoding in [TSInputEncodingUTF16LE, TSInputEncodingUTF16BE] {
            let parser = TreeSitterParser(encoding: encoding)
            parser.language = tree_sitter_javascript()
            let tree = try XCTUnwrap(parser.parse(string))
            XCTAssertFalse(ts_node_has_error(tree.rootNode.rawValue))
            XCTAssertEqual(tree.rootNode.endByte, string.byteCount)
            XCTAssertEqual(tree.rootNode.endPoint.row, 1)
            XCTAssertEqual(tree.rootNode.endPoint.column, UInt32(("let count = 42;" as NSString).byteCount.value))

            let cursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
            cursor.execute()
            let captures = cursor.validCaptures(in: StringView(string: string as String))
            XCTAssertEqual(captures.map(\.name), ["variable", "string", "variable", "number"])
            let expectedRanges = ["café", "\"Grøn 😀\"", "count", "42"].map { ByteRange(utf16Range: string.range(of: $0)) }
            XCTAssertEqual(captures.map(\.byteRange), expectedRanges)
        }
    }

    func testIncrementalUnicodeEditAcrossDelegateReadBoundaryMatchesFreshParse() throws {
        let prefix = "let message = \""
        // The delegate reads 2,048 bytes at a time. Split the emoji's surrogate pair across two reads.
        let padding = String(repeating: "x", count: 1_023 - (prefix as NSString).length)
        let original = "\(prefix)\(padding)😀 café\";\nlet count = 1;" as NSString
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.language = tree_sitter_javascript()
        parser.delegate = delegate
        delegate.string = original
        let originalTree = try XCTUnwrap(parser.parse())
        XCTAssertFalse(ts_node_has_error(originalTree.rootNode.rawValue))
        let freshParser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        freshParser.language = tree_sitter_javascript()
        let freshOriginalTree = try XCTUnwrap(freshParser.parse(original))
        assertNodesEqual(originalTree.rootNode, freshOriginalTree.rootNode)

        let replacedRange = original.range(of: "😀")
        let replacement = "Grøn 🧑‍💻" as NSString
        let edited = original.replacingCharacters(in: replacedRange, with: replacement as String) as NSString
        let startByte = ByteCount(utf16Length: replacedRange.location)
        let oldEndByte = ByteCount(utf16Length: NSMaxRange(replacedRange))
        let newEndByte = startByte + replacement.byteCount
        originalTree.apply(TreeSitterInputEdit(
            startByte: startByte,
            oldEndByte: oldEndByte,
            newEndByte: newEndByte,
            startPoint: TreeSitterTextPoint(row: 0, column: UInt32(startByte.value)),
            oldEndPoint: TreeSitterTextPoint(row: 0, column: UInt32(oldEndByte.value)),
            newEndPoint: TreeSitterTextPoint(row: 0, column: UInt32(newEndByte.value))))
        delegate.string = edited
        let incrementalTree = try XCTUnwrap(parser.parse(oldTree: originalTree))
        let freshTree = try XCTUnwrap(freshParser.parse(edited))
        XCTAssertFalse(ts_node_has_error(incrementalTree.rootNode.rawValue))
        XCTAssertEqual(incrementalTree.rootNode.endByte, edited.byteCount)
        assertNodesEqual(incrementalTree.rootNode, freshTree.rootNode)
    }

    func testParseString() {
        let string: NSString = "let foo = \"Hello world\""
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.delegate = delegate
        parser.language = tree_sitter_javascript()
        let tree = parser.parse(string)
        let expressionString = "(program (lexical_declaration (variable_declarator name: (identifier) value: (string))))"
        XCTAssertEqual(tree?.rootNode.expressionString, expressionString)
    }

    func testReplaceShortTextWithSameShortText() {
        let string: NSString = "let foo = \"Hello world\""
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.delegate = delegate
        parser.language = tree_sitter_javascript()
        let oldTree = parser.parse(string)
        // Replace the entire text but with the same text (Select all and paste: CMD + A, CMD + V)
        let inputEdit = TreeSitterInputEdit(
            startByte: 0,
            oldEndByte: string.byteCount,
            newEndByte: string.byteCount,
            startPoint: TreeSitterTextPoint(row: 0, column: 0),
            oldEndPoint: TreeSitterTextPoint(row: 0, column: 23),
            newEndPoint: TreeSitterTextPoint(row: 0, column: 23))
        oldTree?.apply(inputEdit)
        delegate.string = string
        let newTree = parser.parse(oldTree: oldTree)
        XCTAssertEqual(newTree!.rootNode.expressionString!, oldTree!.rootNode.expressionString!)
    }

    func testReplaceLongTextWithSameLongText() {
        let string: NSString = """
        /**
         * This is a Runestone text view with syntax highlighting
         * for the JavaScript programming language.
         */

        let names = ["Steve Jobs", "Tim Cook", "Eddy Cue"]
        let years = [1955, 1960, 1964]
        printNamesAndYears(names, years)

        // Print the year each person was born.
        function printNamesAndYears(names, years) {
          for (let i = 0; i < names.length; i++) {
            console.log(names[i] + " was born in " + years[i])
          }
        }

        """
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.delegate = delegate
        parser.language = tree_sitter_javascript()
        let oldTree = parser.parse(string)
        // Replace the entire text but with the same text (Select all and paste: CMD + A, CMD + V)
        let inputEdit = TreeSitterInputEdit(
            startByte: 0,
            oldEndByte: 830,
            newEndByte: 830,
            startPoint: TreeSitterTextPoint(row: 0, column: 0),
            oldEndPoint: TreeSitterTextPoint(row: 15, column: 0),
            newEndPoint: TreeSitterTextPoint(row: 15, column: 0))
        oldTree?.apply(inputEdit)
        delegate.string = string
        let newTree = parser.parse(oldTree: oldTree)
        XCTAssertEqual(newTree!.rootNode.expressionString!, oldTree!.rootNode.expressionString!)
    }

    private func assertNodesEqual(_ actual: TreeSitterNode, _ expected: TreeSitterNode, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.type, expected.type, file: file, line: line)
        XCTAssertEqual(actual.byteRange, expected.byteRange, file: file, line: line)
        XCTAssertEqual(actual.startPoint.row, expected.startPoint.row, file: file, line: line)
        XCTAssertEqual(actual.startPoint.column, expected.startPoint.column, file: file, line: line)
        XCTAssertEqual(actual.endPoint.row, expected.endPoint.row, file: file, line: line)
        XCTAssertEqual(actual.endPoint.column, expected.endPoint.column, file: file, line: line)
        XCTAssertEqual(actual.childCount, expected.childCount, file: file, line: line)
        for index in 0 ..< min(actual.childCount, expected.childCount) {
            if let actualChild = actual.child(at: index), let expectedChild = expected.child(at: index) {
                assertNodesEqual(actualChild, expectedChild, file: file, line: line)
            }
        }
    }
}
