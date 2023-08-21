import Combine
import Foundation

struct LineFragmentControllerFactory {
    let selectedRange: CurrentValueSubject<NSRange, Never>
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let rendererFactory: LineFragmentRendererFactory

    func makeLineFragmentController(for lineFragment: LineFragment, in line: LineNode) -> LineFragmentController {
        LineFragmentController(
            line: line,
            lineFragment: lineFragment,
            rendererFactory: rendererFactory,
            selectedRange: selectedRange,
            markedRange: markedRange
        )
    }
}
