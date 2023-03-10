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
    private let rendererFactory: RendererFactory
    private var renderer: Renderer

    init(line: LineNode, lineFragment: LineFragment, rendererFactory: RendererFactory) {
        self.line = line
        self.lineFragment = lineFragment
        self.rendererFactory = rendererFactory
        self.renderer = rendererFactory.makeRenderer(for: lineFragment, in: line)
    }
}
