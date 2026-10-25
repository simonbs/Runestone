import UIKit

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
    var markedTextBackgroundColor: UIColor {
        get {
            renderer.markedTextBackgroundColor
        }
        set {
            if newValue != renderer.markedTextBackgroundColor {
                renderer.markedTextBackgroundColor = newValue
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }
    var markedTextBackgroundCornerRadius: CGFloat {
        get {
            renderer.markedTextBackgroundCornerRadius
        }
        set {
            if newValue != renderer.markedTextBackgroundCornerRadius {
                renderer.markedTextBackgroundCornerRadius = newValue
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
    /// Misspelled ranges in coordinates local to the document line.
    var misspelledRanges: [NSRange] {
        get {
            renderer.misspelledRanges
        }
        set {
            if newValue != renderer.misspelledRanges {
                renderer.misspelledRanges = newValue
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }

    private let renderer: LineFragmentRenderer

    init(lineFragment: LineFragment, invisibleCharacterConfiguration: InvisibleCharacterConfiguration) {
        self.lineFragment = lineFragment
        self.renderer = LineFragmentRenderer(lineFragment: lineFragment, invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        self.renderer.delegate = self
    }

    func visibleCharacterRanges(in horizontalRange: ClosedRange<CGFloat>) -> [NSRange] {
        renderer.visibleCharacterRanges(in: horizontalRange)
    }
}

// MARK: - LineFragmentRendererDelegate
extension LineFragmentController: LineFragmentRendererDelegate {
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? {
        delegate?.string(in: self)
    }
}
