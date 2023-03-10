import Foundation

extension TextViewController {
    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.value.linePosition(at: location) {
            return languageMode.value.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }
}
