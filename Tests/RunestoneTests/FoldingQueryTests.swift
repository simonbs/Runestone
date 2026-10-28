@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

final class FoldingQueryTests: XCTestCase {
    func testRepeatedCapturesFormOneImportFoldAndSingleLineNodesAreIgnored() throws {
        let snapshot = try makeSnapshot("import a from 'a';\nimport b from 'b';\nconst value = 1;",
                                        query: "(import_statement)+ @fold (number) @fold")
        XCTAssertEqual(snapshot.ranges(), [.init(startRow: 0, endRow: 1)])
    }

    func testOffsetExcludesClosingDelimiterWithUnicodeAndCRLF() throws {
        let snapshot = try makeSnapshot("function café() {\r\n  const value = '😀';\r\n}",
                                        query: "((statement_block) @fold (#offset! @fold 0 0 0 -1))")
        XCTAssertEqual(snapshot.ranges(), [.init(startRow: 0, endRow: 1)])
    }

    func testTrimRemovesTrailingBlankLinesAndKeepsPredicateFiltering() throws {
        let text = "const accepted = {\n value: 1\n};\n\n\n"
        let snapshot = try makeSnapshot(text, query: """
        ((program) @fold (#trim! @fold))
        ((object) @fold (#match? @fold "never matches"))
        """)
        XCTAssertEqual(snapshot.ranges(), [.init(startRow: 0, endRow: 2)])
        let untrimmed = try makeSnapshot(text, query: "(program) @fold")
        XCTAssertEqual(untrimmed.ranges(), [.init(startRow: 0, endRow: 4)])
    }

    func testExplicitTrimAndInvalidOffsetsDoNotCreateOutOfBoundsFolds() throws {
        let snapshot = try makeSnapshot("\n\nlet first = 1;\nlet second = 2;\n\n", query: """
        ((program) @fold (#trim! @fold 1 0 1 0))
        ((program) @fold (#offset! @fold -100 0 0 0))
        """)
        XCTAssertEqual(snapshot.ranges(), [.init(startRow: 2, endRow: 3)])
    }

    func testParentPredicateExcludesOnlyDirectParent() throws {
        let snapshot = try makeSnapshot("const a = ({\n value: 1\n});\nconst b = {\n value: 2\n};", query: """
        ((object) @fold (#not-has-parent? @fold parenthesized_expression))
        """)
        XCTAssertEqual(snapshot.ranges(), [.init(startRow: 3, endRow: 5)])
    }

    func testCancellationDiscardsPartialFoldResults() throws {
        let snapshot = try makeSnapshot(String(repeating: "function f() {\n  return 1;\n}\n", count: 100),
                                        query: "(statement_block) @fold")
        var checks = 0
        XCTAssertTrue(snapshot.ranges {
            checks += 1
            return checks >= 10
        }.isEmpty)
        XCTAssertLessThan(checks, 20)
        XCTAssertEqual(snapshot.ranges().count, 100)
    }

    @MainActor
    func testReplacingParseCancelsPendingFoldPublication() {
        let stringView = StringView(string: "function f() {\n return 1;\n}")
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let language = TreeSitterLanguage(tree_sitter_javascript(), foldsQuery: .init(string: "(statement_block) @fold"))
        let mode = TreeSitterInternalLanguageMode(
            language: language.internalLanguage, languageProvider: nil, stringView: stringView, lineManager: lineManager)
        mode.parse(stringView.string)
        let canceled = expectation(description: "Superseded folds discarded")
        mode.foldingRanges { ranges in
            XCTAssertTrue(ranges.isEmpty)
            canceled.fulfill()
        }
        // This test holds the editor thread until the old request is canceled,
        // even if its background extraction has already finished.
        mode.parse("let done = 1;")
        let replacement = expectation(description: "Replacement folds published")
        mode.foldingRanges { ranges in
            XCTAssertTrue(ranges.isEmpty)
            replacement.fulfill()
        }
        wait(for: [canceled, replacement], timeout: 5)
    }

    func testMixedMarkdownSectionsHideEveryLineAfterHeadingStartAndRespectContainers() {
        typealias Heading = TreeSitterFoldingSnapshot.Heading
        let headings = [
            Heading(startRow: 0, level: 1, container: 0, containerEndRow: 15),
            Heading(startRow: 3, level: 2, container: 0, containerEndRow: 15),
            Heading(startRow: 7, level: 3, container: 0, containerEndRow: 15),
            // A quote's H1 must not terminate the surrounding document's H1/H2.
            Heading(startRow: 9, level: 1, container: 1, containerEndRow: 10),
            Heading(startRow: 12, level: 1, container: 0, containerEndRow: 15),
            // A final heading with no body is not foldable.
            Heading(startRow: 15, level: 2, container: 0, containerEndRow: 15)
        ]
        XCTAssertEqual(TreeSitterFoldingSnapshot.sectionRanges(headings), [
            .init(startRow: 0, endRow: 11),
            .init(startRow: 3, endRow: 11),
            .init(startRow: 7, endRow: 11),
            .init(startRow: 9, endRow: 10),
            .init(startRow: 12, endRow: 15)
        ])
    }

    func testSetextHeadingWithoutSectionBodyCanFoldItsUnderline() {
        typealias Heading = TreeSitterFoldingSnapshot.Heading
        // A two-line Setext heading must still fold, even without section text.
        XCTAssertEqual(TreeSitterFoldingSnapshot.sectionRanges([
            Heading(startRow: 0, level: 1, container: 0, containerEndRow: 1)
        ]), [.init(startRow: 0, endRow: 1)])
    }

    @MainActor
    func testFoldDiscoveryIncludesInjectedLanguageWithoutAnyHighlightQueries() {
        let text = "<script>\nfunction f() {\n return 1;\n}\n</script>"
        let javascript = TreeSitterLanguage(tree_sitter_javascript(), foldsQuery: .init(string: "(statement_block) @fold"))
        let html = TreeSitterLanguage(tree_sitter_html(), injectionsQuery: .init(string: """
        ((script_element (raw_text) @injection.content) (#set! injection.language "javascript"))
        """))
        let provider = FoldingLanguageProvider(language: javascript)
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        let mode = TreeSitterInternalLanguageMode(
            language: html.internalLanguage, languageProvider: provider, stringView: stringView, lineManager: lineManager)
        mode.parse(stringView.string)
        XCTAssertEqual(mode.foldingRanges(), [.init(startRow: 1, endRow: 3)])
        let finished = expectation(description: "Background fold extraction")
        mode.foldingRanges { ranges in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(ranges, [.init(startRow: 1, endRow: 3)])
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }

    private func makeSnapshot(_ text: String, query: String) throws -> TreeSitterFoldingSnapshot {
        let parser = TreeSitterParser(encoding: TSInputEncoding.preferredUTF16)
        parser.language = tree_sitter_javascript()
        let tree = try XCTUnwrap(parser.parse(text as NSString))
        let query = try TreeSitterQuery(source: query, language: tree_sitter_javascript())
        return TreeSitterFoldingSnapshot(layers: [.init(tree: tree, query: query)], stringView: StringView(string: text))
    }
}

private final class FoldingLanguageProvider: TreeSitterLanguageProvider {
    let language: TreeSitterLanguage

    init(language: TreeSitterLanguage) { self.language = language }

    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage? {
        languageName == "javascript" ? language : nil
    }
}
