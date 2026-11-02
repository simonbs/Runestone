@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import TreeSitterSupport
import XCTest

final class TreeSitterChangedRangeTests: XCTestCase {
    func testSharedJSONRepetitionsKeepStockChangedRangesForTokenAndStructuralEdits() throws {
        let text = "[\n" + (0..<2_000).map { "  \"value\($0)\"" }.joined(separator: ",\n") + "\n]"
        for replacement in ["value1000x", "Grøn 😀", "value\n1000", "value1000\", 42, \"added", ""] {
            try compareEdit(text, language: tree_sitter_json(), replacing: "value1000", with: replacement)
        }
        // Exercise the accelerated path as well as differential correctness. A
        // shared balanced repetition keeps ordinary character typing bounded.
        let pair = try editedTrees(text, language: tree_sitter_json(), replacing: "value1000", with: "value1000x")
        XCTAssertTrue(runestone_trees_have_same_structure(pair.old.pointer, pair.new.pointer))
        XCTAssertTrue(pair.old.rangesChanged(comparingTo: pair.new).isEmpty)
    }

    func testJavaScriptAliasesUnicodeAndRecoveryKeepStockChangedRanges() throws {
        let text = "const object = { target: \"café 😀\", count: 42 };\nobject.target;"
        for (needle, replacement) in [
            ("target", "renamed"),
            ("😀", "🧑‍💻"),
            ("42", "true"),
            ("42", "{ value: 42 }"),
            ("café 😀", "unterminated\" +"),
            ("object.target;", "")
        ] {
            try compareEdit(text, language: tree_sitter_javascript(), replacing: needle, with: replacement)
        }
    }

    func testExternalScannerHTMLAndBoundaryEditsKeepStockChangedRanges() throws {
        let html = "<div><script>let count = 42;</script><p>café 😀</p></div>"
        for (needle, replacement) in [("42", "43"), ("<script>", "<style>"), ("</div>", ""), (html, "")] {
            try compareEdit(html, language: tree_sitter_html(), replacing: needle, with: replacement)
        }
        for text in ["", "[]", "[\"😀\"]", "[\n 1,\r\n 2\n]"] {
            try compareEdit(text, language: tree_sitter_json(), replacing: "", with: " ", atEnd: false)
            try compareEdit(text, language: tree_sitter_json(), replacing: "", with: "\n", atEnd: true)
            try compareEdit(text, language: tree_sitter_json(), replacing: text, with: "")
        }
    }

    func testIncludedRangeChangesCannotUseTheStructuralProof() throws {
        let parser = TreeSitterParser(encoding: .preferredUTF16)
        parser.language = tree_sitter_javascript()
        let text = "let first = 1;\nlet second = 2;" as NSString
        let old = try XCTUnwrap(parser.parse(text))
        let lastLineStart = text.range(of: "let second").location
        XCTAssertTrue(parser.setIncludedRanges([TreeSitterTextRange(
            startPoint: TreeSitterTextPoint(row: 0, column: 0),
            endPoint: TreeSitterTextPoint(row: 1, column: UInt32((text.length - lastLineStart) * 2)),
            startByte: 0, endByte: text.byteCount)]))
        let new = try XCTUnwrap(parser.parse(text))
        XCTAssertFalse(runestone_trees_have_same_structure(old.pointer, new.pointer))
        assertSameChangedRanges(old, new)
    }

    func testRepeatedMutationSequencesKeepStockRangesThroughRecoveryAndSharedTreeEdits() throws {
        let fixtures: [(language: OpaquePointer, text: String)] = [
            (tree_sitter_json(), "[\r\n {\"label\": \"seed\", \"count\": 1},\n [2, 3, \"😀\"]\r\n]"),
            (tree_sitter_javascript(), "const object = { label: \"seed\", count: 1 };\r\nobject.label; // 😀\n"),
            (tree_sitter_html(), "<div data-name=\"seed\"><script>let count = 1;</script>\r\n<p>😀</p></div>")
        ]
        for fixture in fixtures {
            try runMutationSequence(fixture.text, language: fixture.language)
        }
    }

    private func runMutationSequence(_ original: String, language: OpaquePointer) throws {
        let stringView = StringView(string: original)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let parser = TreeSitterParser(encoding: .preferredUTF16)
        parser.language = language
        let delegate = MockTreeSitterParserDelegate()
        delegate.string = stringView.string
        parser.delegate = delegate
        var tree = try XCTUnwrap(parser.parse())
        let editor = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: .lf)
        var randomState: UInt64 = 0x8D31_74A2
        for step in 0..<300 {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
            let mutation = mutation(at: step, in: stringView.string, original: original, randomState: randomState)
            let change = editor.replaceText(in: mutation.range, with: mutation.text).textChange
            tree.apply(TreeSitterInputEdit(
                startByte: change.byteRange.location, oldEndByte: change.byteRange.upperBound,
                newEndByte: change.byteRange.location + change.bytesAdded,
                startPoint: TreeSitterTextPoint(change.startLinePosition),
                oldEndPoint: TreeSitterTextPoint(change.oldEndLinePosition),
                newEndPoint: TreeSitterTextPoint(change.newEndLinePosition)))
            delegate.string = stringView.string
            let new = try XCTUnwrap(parser.parse(oldTree: tree))
            assertSameChangedRanges(tree, new, context: "Mutation \(step) of \(original)")
            tree = new
        }
    }

    private func mutation(at step: Int, in text: NSString, original: String, randomState: UInt64)
    -> (range: NSRange, text: String) {
        let entireText = NSRange(location: 0, length: text.length)
        let randomCharacter = text.length == 0 ? NSRange(location: 0, length: 0)
            : text.customRangeOfComposedCharacterSequence(at: Int(randomState % UInt64(text.length)))
        switch step % 12 {
        case 0, 8:
            return (entireText, original)
        case 1, 9:
            return (text.range(of: "seed"), step % 12 == 1 ? "café 😀" : "Grøn 🧑‍💻")
        case 2:
            return (text.range(of: "1"), "123")
        case 3:
            return (NSRange(location: text.length, length: 0), "\r\n")
        case 4:
            return (randomCharacter, "")
        case 5:
            return (NSRange(location: randomCharacter.location, length: 0), "\"")
        case 6:
            let first = text.length == 0 ? entireText : text.customRangeOfComposedCharacterSequence(at: 0)
            return (first, "")
        case 7:
            return (entireText, "")
        case 10:
            return (randomCharacter, "{{")
        default:
            return (NSRange(location: randomCharacter.location, length: 0), "\n")
        }
    }

    private func compareEdit(_ text: String, language: OpaquePointer, replacing needle: String,
                             with replacement: String, atEnd: Bool = false,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let pair = try editedTrees(text, language: language, replacing: needle, with: replacement, atEnd: atEnd)
        assertSameChangedRanges(pair.old, pair.new, file: file, line: line)
    }

    private func editedTrees(_ text: String, language: OpaquePointer, replacing needle: String,
                             with replacement: String, atEnd: Bool = false) throws
    -> (old: TreeSitterTree, new: TreeSitterTree) {
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let parser = TreeSitterParser(encoding: .preferredUTF16)
        parser.language = language
        let delegate = MockTreeSitterParserDelegate()
        delegate.string = stringView.string
        parser.delegate = delegate
        let old = try XCTUnwrap(parser.parse())
        let range = needle.isEmpty
            ? NSRange(location: atEnd ? stringView.string.length : 0, length: 0)
            : stringView.string.range(of: needle)
        XCTAssertNotEqual(range.location, NSNotFound)
        let editor = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: .lf)
        let change = editor.replaceText(in: range, with: replacement).textChange
        old.apply(TreeSitterInputEdit(
            startByte: change.byteRange.location, oldEndByte: change.byteRange.upperBound,
            newEndByte: change.byteRange.location + change.bytesAdded,
            startPoint: TreeSitterTextPoint(change.startLinePosition),
            oldEndPoint: TreeSitterTextPoint(change.oldEndLinePosition),
            newEndPoint: TreeSitterTextPoint(change.newEndLinePosition)))
        delegate.string = stringView.string
        return (old, try XCTUnwrap(parser.parse(oldTree: old)))
    }

    private func assertSameChangedRanges(_ old: TreeSitterTree, _ new: TreeSitterTree, context: String = "",
                                         file: StaticString = #filePath, line: UInt = #line) {
        var count: UInt32 = 0
        let stock = ts_tree_get_changed_ranges(old.pointer, new.pointer, &count)
        defer { free(stock) }
        let expected = UnsafeBufferPointer(start: stock, count: Int(count)).map { range in
            [range.start_byte, range.end_byte, range.start_point.row, range.start_point.column,
             range.end_point.row, range.end_point.column]
        }
        let actual = old.rangesChanged(comparingTo: new).map { range in
            [UInt32(range.startByte.value), UInt32(range.endByte.value), range.startPoint.row, range.startPoint.column,
             range.endPoint.row, range.endPoint.column]
        }
        XCTAssertEqual(actual, expected, context, file: file, line: line)
    }
}
