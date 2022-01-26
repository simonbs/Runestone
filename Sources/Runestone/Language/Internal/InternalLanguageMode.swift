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

struct InsertLineBreakIndentStrategy {
    let indentLevel: Int
    let insertExtraLineBreak: Bool
}

protocol InternalLanguageMode: AnyObject {
    func parse(_ text: NSString)
    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void))
    func textDidChange(_ change: LanguageModeTextChange) -> LanguageModeTextChangeResult
    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter
    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode?
    func currentIndentLevel(of line: DocumentLineNode, using indentStrategy: IndentStrategy) -> Int
    func strategyForInsertingLineBreak(
        from startLinePosition: LinePosition,
        to endLinePosition: LinePosition,
        using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy
    func detectIndentStrategy() -> DetectedIndentStrategy
}
