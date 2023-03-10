import Combine
import Foundation

final class PlainTextInternalLanguageMode: InternalLanguageMode {
    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>

    init(stringView: StringView, lineManager: LineManager) {
        self.stringView = CurrentValueSubject(stringView)
        self.lineManager = CurrentValueSubject(lineManager)
    }

    func parse(_ text: NSString) {}

    func parse(_ text: NSString, completion: @escaping ((Bool) -> Void)) {
        completion(true)
    }

    func textDidChange(_ change: TextStoreChange) -> LineChangeSet {
        LineChangeSet()
    }

    func tokenType(at location: Int) -> String? {
        nil
    }

    func createSyntaxHighlighter(with theme: CurrentValueSubject<Theme, Never>) -> SyntaxHighlighter {
        PlainTextSyntaxHighlighter()
    }

    func highestSyntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        nil
    }

    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        nil
    }

    func currentIndentLevel(of line: LineNode, using indentStrategy: IndentStrategy) -> Int {
        0
    }

    func strategyForInsertingLineBreak(
        from startLinePosition: LinePosition,
        to endLinePosition: LinePosition,
        using indentStrategy: IndentStrategy) -> InsertLineBreakIndentStrategy {
        InsertLineBreakIndentStrategy(indentLevel: 0, insertExtraLineBreak: false)
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
        .unknown
    }
}
