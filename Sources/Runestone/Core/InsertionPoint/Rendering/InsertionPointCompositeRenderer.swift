import _RunestoneMultiPlatform
import CoreGraphics
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

struct InsertionPointCompositeRenderer: InsertionPointRenderer {
    let needsRender: AnyPublisher<Bool, Never>

    private let renderers: [InsertionPointRenderer]

    init(renderers: [InsertionPointRenderer]) {
        self.renderers = renderers
        self.needsRender = Publishers.MergeMany(
            renderers.map(\.needsRender)
        ).eraseToAnyPublisher()
    }

    func render(_ rect: CGRect, to context: CGContext) {
        if let context = UIGraphicsGetCurrentContext() {
            for renderer in renderers {
                renderer.render(rect, to: context)
            }
        }
    }
}
