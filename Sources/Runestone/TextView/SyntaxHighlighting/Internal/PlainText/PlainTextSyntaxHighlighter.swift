import Combine
import CoreGraphics
import Foundation

final class PlainTextSyntaxHighlighter: LineSyntaxHighlighter {
    let theme: CurrentValueSubject<Theme, Never>
    let kern: CurrentValueSubject<CGFloat, Never>
    let canHighlight = false

    init(theme: CurrentValueSubject<Theme, Never>, kern: CurrentValueSubject<CGFloat, Never>) {
        self.theme = theme
        self.kern = kern
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {}

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        completion(.success(()))
    }

    func cancel() {}
}
