import Combine

final class SyntaxNodeRaycaster {
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>

    init(
        lineManager: CurrentValueSubject<LineManager, Never>,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    ) {
        self.lineManager = lineManager
        self.languageMode = languageMode
    }

    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.value.linePosition(at: location) {
            return languageMode.value.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }
}
