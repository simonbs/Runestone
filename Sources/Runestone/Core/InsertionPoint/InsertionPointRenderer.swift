import CoreGraphics
import Foundation

struct InsertionPointRenderer {
    let backgroundRenderer: InsertionPointBackgroundRenderer
    let foregroundRenderer: InsertionPointForegroundRenderer

    func render(in rect: CGRect, to context: CGContext) {
        if let context = UIGraphicsGetCurrentContext() {
            backgroundRenderer.render(rect, to: context)
            foregroundRenderer.render(rect, to: context)
        }
    }
}
