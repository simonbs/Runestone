//
//  PlainTextLanguageMode.swift
//  
//
//  Created by Simon Støvring on 14/02/2021.
//

import Foundation

final class PlainTextLanguageMode: LanguageMode {
    func parse(_ text: NSString) {}

    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
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

    func currentIndentLevel(of line: DocumentLineNode, using indentStrategy: IndentStrategy) -> Int {
        return 0
    }

    func strategyForInsertingLineBreak(
        from startLinePosition: LinePosition,
        to endLinePosition: LinePosition,
        using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy {
        return InsertLineBreakIndentStrategy(indentLevel: 0, insertExtraLineBreak: false)
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
        return .unknown
    }
}
