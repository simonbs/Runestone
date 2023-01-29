@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

final class TreeSitterParserTests: XCTestCase {
    private let delegate = MockTreeSitterParserDelegate()

    func testParseString() {
        let string: NSString = "let foo = \"Hello world\""
        let parser = TreeSitterParser(encoding: TSInputEncodingUTF16)
        parser.delegate = delegate
        parser.language = tree_sitter_javascript()
        let tree = parser.parse(string)
        let expressionString = "(program (lexical_declaration (variable_declarator name: (identifier) value: (string))))"
        XCTAssertEqual(tree?.rootNode.expressionString, expressionString)
    }

    func testReplaceShortTextWithSameShortText() {
        let string: NSString = "let foo = \"Hello world\""
        let parser = TreeSitterParser(encoding: TSInputEncodingUTF16)
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
            newEndPoint: TreeSitterTextPoint(row: 0, column: 23)
        )
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
        let parser = TreeSitterParser(encoding: TSInputEncodingUTF16)
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
            newEndPoint: TreeSitterTextPoint(row: 15, column: 0)
        )
        oldTree?.apply(inputEdit)
        delegate.string = string
        let newTree = parser.parse(oldTree: oldTree)
        XCTAssertEqual(newTree!.rootNode.expressionString!, oldTree!.rootNode.expressionString!)
    }
}
