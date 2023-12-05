import Foundation

final class LineFragmentController<LineFragmentType: LineFragment> {
    var lineFragment: LineFragmentType {
        didSet {
            if lineFragment != oldValue {
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
    private let rendererFactory: LineFragmentRendererFactory<LineFragmentType>

    init(
        line: LineNode,
        lineFragment: LineFragmentType,
        rendererFactory: LineFragmentRendererFactory<LineFragmentType>
    ) {
        self.line = line
        self.lineFragment = lineFragment
        self.rendererFactory = rendererFactory
        self.renderer = rendererFactory.makeRenderer(for: lineFragment, in: line)
//        Publishers.CombineLatest(selectedRange, markedRange).sink { [weak self] _, _ in
//            self?.lineFragmentView?.setNeedsDisplay()
//        }.store(in: &cancellables)
    }
}
