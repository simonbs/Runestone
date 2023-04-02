import Combine
import CoreGraphics
import Foundation

final class PlainTextSyntaxHighlighter: SyntaxHighlighter {
    let canHighlight = false

    func syntaxHighlight(_ input: SyntaxHighlighterInput) {}

    func syntaxHighlight(_ input: SyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        completion(.success(()))
    }

    func cancel() {}
}
