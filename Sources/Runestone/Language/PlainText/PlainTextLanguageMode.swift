//
//  PlainTextLanguageMode.swift
//  
//
//  Created by Simon Støvring on 14/02/2021.
//

import Foundation

final class PlainTextLanguageMode: LanguageMode {
    func parse(_ text: String) {}

    func parse(_ text: String, completion: @escaping ((Bool) -> Void)) {
        completion(true)
    }

    func textDidChange(_ change: LanguageModeTextChange) -> LanguageModeTextChangeResult {
        return LanguageModeTextChangeResult(changedRows: [])
    }

    func tokenType(at location: Int) -> String? {
        return nil
    }

    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter {
        return PlainTextSyntaxHighlighter()
    }

    func highestSyntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        return nil
    }

    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        return nil
    }

    func suggestedIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        return 0
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        return 0
    }

    func behaviorForInsertingLineBreak(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> LanguageModeLineBreakIndentBehavior {
        return LanguageModeLineBreakIndentBehavior(indentLevel: 0, insertExtraLineBreak: false)
    }
}
