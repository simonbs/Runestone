import Combine

struct SyntaxNodeRaycaster<LineManagerType: LineManaging, LanguageModeType: InternalLanguageMode> {
    let lineManager: LineManagerType
    let languageMode: LanguageModeType

    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.linePosition(at: location) {
            return languageMode.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }
}
