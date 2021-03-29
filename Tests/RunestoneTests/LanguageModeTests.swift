import XCTest
@testable import Runestone
import TestTreeSitterLanguages

final class LanguageModeTests: XCTestCase {
//    func testCurretIndent() {
//        // if (foo == "bar") {
//        //   if (hello == "world") {
//        //     console.log("Hi")
//        //   }
//        // }
//        let text = "if (foo == \"bar\") {\n   if (hello == \"world\") {\n     console.log(\"Hi\")\n  }\n}"
//        let language = TreeSitterLanguage(tree_sitter_javascript(), textEncoding: .utf8)
//        let stringView = StringView(string: text)
//        let lineManager = LineManager(stringView: stringView)
//        lineManager.rebuild(from: text as NSString)
//        let languageMode = TreeSitterLanguageMode(language: language, stringView: stringView, lineManager: lineManager)
//        let line = lineManager.line(atRow: 1)
//        languageMode.currentIndentLevel(of: <#T##DocumentLineNode#>, using: <#T##IndentStrategy#>)
//    }
}

extension LanguageModeTests {
    func javaScriptLanguageMode(text: String) -> TreeSitterLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(
            indent: [
                "array",
                "object",
                "arguments",
                "statement_block",
                "class_body",
                "parenthesized_expression",
                "jsx_element",
                "jsx_opening_element",
                "jsx_expression",
                "switch_body"
            ],
            outdent: [
                "else",
                "}",
                "]"
            ])
        let language = TreeSitterLanguage(tree_sitter_javascript(), textEncoding: .utf8, indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text)
        return languageMode
    }

    func jsonLanguageMode(text: String) -> TreeSitterLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(indent: ["object", "array"], outdent: ["}", "]"])
        let language = TreeSitterLanguage(tree_sitter_json(), textEncoding: .utf8, indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text)
        return languageMode
    }

    func htmlLanguageMode(text: String) -> TreeSitterLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(indent: ["start_tag", "element"], outdent: ["end_tag"])
        let language = TreeSitterLanguage(tree_sitter_html(), textEncoding: .utf8, indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text)
        return languageMode
    }

    func pythonLanguageMode(text: String) -> TreeSitterLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(
            indent: [
                "function_definition",
                "for_statement",
                "class_definition",
                "elif_clause",
                "else_clause",
                "except_clause",
                "while_statement",
                "if_statement",
                "try_statement"
            ],
            indentScanLocation: .lineStart)
        let language = TreeSitterLanguage(tree_sitter_python(), textEncoding: .utf8, indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text)
        return languageMode
    }

    func languageMode(language: TreeSitterLanguage, text: String) -> TreeSitterLanguageMode {
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild(from: text as NSString)
        return TreeSitterLanguageMode(language: language, stringView: stringView, lineManager: lineManager)
    }
}
