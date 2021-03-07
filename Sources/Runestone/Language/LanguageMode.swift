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

protocol LanguageMode: AnyObject {
    func parse(_ text: String)
    func parse(_ text: String, completion: @escaping ((Bool) -> Void))
    func textDidChange(_ change: LanguageModeTextChange) -> LanguageModeTextChangeResult
    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter
    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode?
    func shouldInsertDoubleLineBreak(replacingRangeFrom startLinePosition: LinePosition, to endLinePosition: LinePosition) -> Bool
    func suggestedIndentLevel(for line: DocumentLineNode) -> Int
    func suggestedIndentLevel(at location: Int, in line: DocumentLineNode) -> Int
    func indentLevel(in line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int
}
