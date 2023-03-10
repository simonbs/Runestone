import Combine
import Foundation

protocol SyntaxHighlighter: AnyObject {
    typealias AsyncCallback = (Result<Void, Error>) -> Void
    var canHighlight: Bool { get }
    func syntaxHighlight(_ input: SyntaxHighlighterInput)
    func syntaxHighlight(_ input: SyntaxHighlighterInput, completion: @escaping AsyncCallback)
    func cancel()
}
