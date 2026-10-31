import RunestoneSyntax
import TestTreeSitterLanguages
import XCTest

final class RunestoneSyntaxHighlighterTests: XCTestCase {
    func testHighlightsUnicodeUsingAbsoluteUTF16Ranges() throws {
        let highlighter = try makeHighlighter()
        let text = "let ignored = 1\nlet target = \"Grøn 😀\"\n"
        let updated = expectation(description: "parsed")
        highlighter.update(text) { result in
            if case .failure(let error) = result { XCTFail("Parse failed: \(error)") }
            updated.fulfill()
        }
        wait(for: [updated], timeout: 5)

        let captures = expectation(description: "captures")
        highlighter.captures(in: NSRange(location: 0, length: (text as NSString).length)) { result in
            XCTAssertEqual(try? result.get(), [
                RunestoneSyntaxCapture(range: (text as NSString).range(of: "1"), name: "number"),
                RunestoneSyntaxCapture(range: (text as NSString).range(of: "\"Grøn 😀\""), name: "string"),
                RunestoneSyntaxCapture(range: (text as NSString).range(of: "Grøn 😀"), name: "identifier.target")
            ])
            captures.fulfill()
        }
        wait(for: [captures], timeout: 5)
    }

    func testIncrementalUpdatePublishesOnlyNewestGeneration() throws {
        let highlighter = try makeHighlighter()
        let first = expectation(description: "first cancelled")
        highlighter.update(String(repeating: "let target = 1\n", count: 20_000)) { result in
            if case .failure(.cancelled) = result { first.fulfill() }
        }
        let secondText = "let target = 42\n"
        let second = expectation(description: "second parsed")
        highlighter.update(secondText) { result in
            if case .failure(let error) = result { XCTFail("Parse failed: \(error)") }
            second.fulfill()
        }
        wait(for: [first, second], timeout: 10)

        let captures = expectation(description: "new captures")
        highlighter.captures(in: NSRange(location: 0, length: (secondText as NSString).length)) { result in
            XCTAssertEqual(try? result.get().last?.range, (secondText as NSString).range(of: "42"))
            captures.fulfill()
        }
        wait(for: [captures], timeout: 5)
    }

    func testExplicitCancellationCompletesPendingUpdate() throws {
        let highlighter = try makeHighlighter()
        let cancelled = expectation(description: "cancelled")
        highlighter.update(String(repeating: "let target = 1\n", count: 100_000)) { result in
            if case .failure(.cancelled) = result { cancelled.fulfill() }
        }
        highlighter.cancel()
        wait(for: [cancelled], timeout: 5)
    }

    func testAppliesTextPredicates() throws {
        let highlighter = try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_json(),
            highlightsQuery: """
            ((number) @number.special (#eq? @number.special "42"))
            (number) @number
            """))
        let text = "[1, 42]"
        let updated = expectation(description: "parsed")
        highlighter.update(text) { result in
            if case .failure(let error) = result { XCTFail("Parse failed: \(error)") }
            updated.fulfill()
        }
        wait(for: [updated], timeout: 5)
        let captured = expectation(description: "captured")
        highlighter.captures(in: NSRange(location: 0, length: (text as NSString).length)) { result in
            XCTAssertEqual(try? result.get().filter { $0.name == "number.special" }, [
                RunestoneSyntaxCapture(range: (text as NSString).range(of: "42"), name: "number.special")
            ])
            captured.fulfill()
        }
        wait(for: [captured], timeout: 5)
    }

    func testProducesFoldRanges() throws {
        let highlighter = try makeHighlighter()
        let text = "{\n  \"value\": 1\n}\n"
        let updated = expectation(description: "parsed")
        highlighter.update(text) { result in
            if case .failure(let error) = result { XCTFail("Parse failed: \(error)") }
            updated.fulfill()
        }
        wait(for: [updated], timeout: 5)
        let folded = expectation(description: "folds")
        highlighter.folds { result in
            XCTAssertEqual(try? result.get(), [RunestoneSyntaxFold(range: NSRange(location: 0, length: 16))])
            folded.fulfill()
        }
        wait(for: [folded], timeout: 5)
    }

    private func makeHighlighter() throws -> RunestoneSyntaxHighlighter {
        try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_json(),
            highlightsQuery: """
            (string (string_content) @identifier.target)
            (string) @string
            (number) @number
            """,
            foldsQuery: "(object) @fold"))
    }
}
