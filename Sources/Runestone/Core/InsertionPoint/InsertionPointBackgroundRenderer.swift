import Combine
import CoreGraphics

final class InsertionPointBackgroundRenderer {
    var color: MultiPlatformColor = .background

    func render(_ rect: CGRect, to context: CGContext) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.fill(rect)
        context.restoreGState()
    }
}
