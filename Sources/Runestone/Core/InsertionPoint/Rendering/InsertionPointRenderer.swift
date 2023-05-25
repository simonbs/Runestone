import Combine
import CoreGraphics

protocol InsertionPointRenderer {
    var needsRender: AnyPublisher<Bool, Never> { get }
    func render(_ rect: CGRect, to context: CGContext)
}
