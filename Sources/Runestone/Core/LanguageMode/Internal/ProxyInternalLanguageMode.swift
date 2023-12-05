import Combine
import Foundation

final class ProxyInternalLanguageMode: InternalLanguageMode {
    var languageMode: any InternalLanguageMode

    init(languageMode: some InternalLanguageMode) {
        self.languageMode = languageMode
    }

    func parse(_ text: NSString) {
        languageMode.parse(text)
    }
    
    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
        languageMode.parse(text, completion: completion)
    }
    
    func textDidChange(_ change: TextEdit) -> LineChangeSet {
        languageMode.textDidChange(change)
    }
    
    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        languageMode.syntaxNode(at: linePosition)
    }
    
    func strategyForInsertingLineBreak(
        from startLinePosition: LinePosition, 
        to endLinePosition: LinePosition,
        using indentStrategy: IndentStrategy
    ) -> InsertLineBreakIndentStrategy {
        languageMode.strategyForInsertingLineBreak(
            from: startLinePosition,
            to: endLinePosition,
            using: indentStrategy
        )
    }
    
    func detectIndentStrategy() -> DetectedIndentStrategy {
        languageMode.detectIndentStrategy()
    }

    func createSyntaxHighlighter(with theme: Theme) -> any SyntaxHighlighter {
        languageMode.createSyntaxHighlighter(with: theme)
    }
}
