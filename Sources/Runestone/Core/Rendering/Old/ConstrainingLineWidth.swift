//import Foundation
//
//struct ConstrainingLineWidth {
//    var rawValue: CGFloat {
//        if lineWrappingState.isLineWrappingEnabled {
//            return viewport.width - textContainerInset.rawValue.left - textContainerInset.rawValue.right
//        } else {
//            // Rendering multiple very long lines is very expensive.
//            // In order to let the editor remain useable, we set a very
//            // high maximum line width when line wrapping is disabled.
//            return 10_000
//        }
//    }
//
//    let viewport: Viewport
//    let textContainerInset: TextContainerInset
//    let lineWrappingState: LineWrappingState
//}
