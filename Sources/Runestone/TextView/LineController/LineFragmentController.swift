import Combine
import Foundation

protocol LineFragmentControllerDelegate: AnyObject {
    func string(in controller: LineFragmentController) -> String?
}

final class LineFragmentController {
    weak var delegate: LineFragmentControllerDelegate?
    var lineFragment: LineFragment {
        didSet {
            if lineFragment !== oldValue {
                renderer.lineFragment = lineFragment
                lineFragmentView?.setNeedsDisplay()
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
    var markedRange: NSRange? {
        get {
            renderer.markedRange
        }
        set {
            if newValue != renderer.markedRange {
                renderer.markedRange = newValue
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }
    var highlightedRangeFragments: [HighlightedRangeFragment] {
        get {
            renderer.highlightedRangeFragments
        }
        set {
            if newValue != renderer.highlightedRangeFragments {
                renderer.highlightedRangeFragments = newValue
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }

    private let renderer: LineFragmentRenderer
    private var cancellables: Set<AnyCancellable> = []

    init(
        lineFragment: LineFragment,
        invisibleCharacterSettings: InvisibleCharacterSettings,
        markedTextBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
        markedTextBackgroundCornerRadius: CurrentValueSubject<CGFloat, Never>
    ) {
        self.lineFragment = lineFragment
        self.renderer = LineFragmentRenderer(
            lineFragment: lineFragment,
            invisibleCharacterSettings: invisibleCharacterSettings,
            markedTextBackgroundColor: markedTextBackgroundColor,
            markedTextBackgroundCornerRadius: markedTextBackgroundCornerRadius
        )
        self.renderer.delegate = self
        Publishers.CombineLatest(
            markedTextBackgroundColor.removeDuplicates(),
            markedTextBackgroundCornerRadius.removeDuplicates()
        ).sink { [weak self] _ in
            self?.lineFragmentView?.setNeedsDisplay()
        }.store(in: &cancellables)
    }
}

// MARK: - LineFragmentRendererDelegate
extension LineFragmentController: LineFragmentRendererDelegate {
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? {
        delegate?.string(in: self)
    }
}
