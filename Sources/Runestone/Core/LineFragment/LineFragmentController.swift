import Combine
import Foundation

final class LineFragmentController {
    var lineFragment: LineFragment {
        didSet {
            if lineFragment !== oldValue {
                renderer = rendererFactory.makeRenderer(for: lineFragment, in: line)
                lineFragmentView?.renderer = renderer
            }
        }
    }
    weak var lineFragmentView: LineFragmentView? {
        didSet {
            if lineFragmentView !== oldValue || lineFragmentView?.renderer !== renderer {
                lineFragmentView?.renderer = renderer
            }
        }
    }

    private let line: LineNode
    private var renderer: LineFragmentRenderer
    private let rendererFactory: LineFragmentRendererFactory
    private var cancellables: Set<AnyCancellable> = []

    init(
        line: LineNode,
        lineFragment: LineFragment,
        rendererFactory: LineFragmentRendererFactory,
        selectedRange: CurrentValueSubject<NSRange, Never>
    ) {
        self.line = line
        self.lineFragment = lineFragment
        self.renderer = rendererFactory.makeRenderer(for: lineFragment, in: line)
        self.rendererFactory = rendererFactory
        selectedRange.sink { [weak self] _ in
            self?.lineFragmentView?.setNeedsDisplay()
        }.store(in: &cancellables)
    }
}
