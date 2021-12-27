@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class LanguageModeTests: XCTestCase {}

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
        let language = TreeSitterLanguage(tree_sitter_javascript(), indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text as NSString)
        return languageMode
    }

    func jsonLanguageMode(text: String) -> TreeSitterLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(indent: ["object", "array"], outdent: ["}", "]"])
        let language = TreeSitterLanguage(tree_sitter_json(), indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text as NSString)
        return languageMode
    }

    func htmlLanguageMode(text: String) -> TreeSitterLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(indent: ["start_tag", "element"], outdent: ["end_tag"])
        let language = TreeSitterLanguage(tree_sitter_html(), indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text as NSString)
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
        let language = TreeSitterLanguage(tree_sitter_python(), indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text as NSString)
        return languageMode
    }

    func languageMode(language: TreeSitterLanguage, text: String) -> TreeSitterLanguageMode {
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild(from: text as NSString)
        return TreeSitterLanguageMode(language: language, stringView: stringView, lineManager: lineManager)
    }
}
