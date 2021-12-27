@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class InternalLanguageModeTests: XCTestCase {}

extension InternalLanguageModeTests {
    func javaScriptLanguageMode(text: String) -> TreeSitterInternalLanguageMode {
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

    func jsonLanguageMode(text: String) -> TreeSitterInternalLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(indent: ["object", "array"], outdent: ["}", "]"])
        let language = TreeSitterLanguage(tree_sitter_json(), indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text as NSString)
        return languageMode
    }

    func htmlLanguageMode(text: String) -> TreeSitterInternalLanguageMode {
        let indentationScopes = TreeSitterIndentationScopes(indent: ["start_tag", "element"], outdent: ["end_tag"])
        let language = TreeSitterLanguage(tree_sitter_html(), indentationScopes: indentationScopes)
        let languageMode = languageMode(language: language, text: text)
        languageMode.parse(text as NSString)
        return languageMode
    }

    func pythonLanguageMode(text: String) -> TreeSitterInternalLanguageMode {
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

    func languageMode(language: TreeSitterLanguage, text: String) -> TreeSitterInternalLanguageMode {
        let stringView = StringView(string: text)
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild(from: text as NSString)
        return TreeSitterInternalLanguageMode(language: language, languageProvider: nil, stringView: stringView, lineManager: lineManager)
    }
}
