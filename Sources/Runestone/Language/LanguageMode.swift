//
//  LanguageMode.swift
//  
//
//  Created by Simon Støvring on 11/02/2021.
//

import Foundation

struct LanguageModeTextChange {
    let byteRange: ByteRange
    let newString: String
    let oldEndLinePosition: LinePosition
    let startLinePosition: LinePosition
    let newEndLinePosition: LinePosition
}

struct LanguageModeTextChangeResult {
    let changedRows: Set<Int>
}

struct LanguageModeLineBreakIndentBehavior {
    let indentLevel: Int
    let insertExtraLineBreak: Bool
}

protocol LanguageMode: AnyObject {
    func parse(_ text: String)
    func parse(_ text: String, completion: @escaping ((Bool) -> Void))
    func textDidChange(_ change: LanguageModeTextChange) -> LanguageModeTextChangeResult
    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter
    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode?
    func suggestedIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int
    func currentIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int
    func behaviorForInsertingLineBreak(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> LanguageModeLineBreakIndentBehavior
}
