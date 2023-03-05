import Foundation

extension TextViewController {
    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.linePosition(at: location) {
            return languageMode.value.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }
}
