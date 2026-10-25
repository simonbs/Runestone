@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

final class TreeSitterSyntaxHighlightingTests: XCTestCase {
    func testHighlightEmbeddedJavaScriptWithUnicodeAndTextPredicates() throws {
        let javaScript = TreeSitterLanguage(
            tree_sitter_javascript(),
            highlightsQuery: .init(string: """
            ((identifier) @keyword (#eq? @keyword "target"))
            (string) @string
            (number) @number
            """))
        let html = TreeSitterLanguage(
            tree_sitter_html(),
            highlightsQuery: .init(string: "(tag_name) @type"),
            injectionsQuery: .init(string: """
            ((script_element (raw_text) @injection.content)
             (#set! injection.language "javascript"))
            """))
        let theme = DefaultTheme()
        let provider = JavaScriptLanguageProvider(language: javaScript)
        let highlighter = StringSyntaxHighlighter(theme: theme, language: html, languageProvider: provider)
        let text = "<p>target 😀</p><script>let target = \"Grøn 😀\"; let ignored = 42;</script>"
        let highlighted = highlighter.syntaxHighlight(text)
        let source = text as NSString

        XCTAssertEqual(highlighted.string, text)
        assertColor(theme.textColor, in: source.range(of: "target 😀"), of: highlighted)
        assertColor(try XCTUnwrap(theme.textColor(for: "type")), in: source.range(of: "script"), of: highlighted)
        let scriptTarget = source.range(of: "target", options: .backwards)
        assertColor(try XCTUnwrap(theme.textColor(for: "keyword")), in: scriptTarget, of: highlighted)
        assertColor(try XCTUnwrap(theme.textColor(for: "string")), in: source.range(of: "\"Grøn 😀\""), of: highlighted)
        assertColor(try XCTUnwrap(theme.textColor(for: "number")), in: source.range(of: "42"), of: highlighted)
        assertColor(theme.textColor, in: source.range(of: "ignored"), of: highlighted)
        assertColor(theme.textColor, in: source.range(of: ";"), of: highlighted)
    }

    private func assertColor(_ expected: UIColor, in range: NSRange, of string: NSAttributedString,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(range.location, NSNotFound, file: file, line: line)
        guard range.location != NSNotFound else {
            return
        }
        string.enumerateAttribute(.foregroundColor, in: range) { value, _, _ in
            XCTAssertEqual(value as? UIColor, expected, file: file, line: line)
        }
    }
}

private final class JavaScriptLanguageProvider: TreeSitterLanguageProvider {
    private let language: TreeSitterLanguage

    init(language: TreeSitterLanguage) {
        self.language = language
    }

    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage? {
        languageName == "javascript" ? language : nil
    }
}
