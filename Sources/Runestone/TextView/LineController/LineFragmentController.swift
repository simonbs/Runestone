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
    var invisibleCharacterConfiguration: InvisibleCharacterConfiguration {
        get {
            return renderer.invisibleCharacterConfiguration
        }
        set {
            renderer.invisibleCharacterConfiguration = newValue
        }
    }
    var markedRange: NSRange? {
        didSet {
            if markedRange != oldValue {
                renderer.markedRange = markedRange
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }
    var markedTextBackgroundColor: UIColor {
        get {
            return renderer.markedTextBackgroundColor
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
            return renderer.markedTextBackgroundCornerRadius
        }
        set {
            if newValue != renderer.markedTextBackgroundCornerRadius {
                renderer.markedTextBackgroundCornerRadius = newValue
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }

    private let renderer: LineFragmentRenderer

    init(lineFragment: LineFragment) {
        self.lineFragment = lineFragment
        self.renderer = LineFragmentRenderer(lineFragment: lineFragment)
        self.renderer.delegate = self
    }
}

// MARK: - LineFragmentRendererDelegate
extension LineFragmentController: LineFragmentRendererDelegate {
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? {
        return delegate?.string(in: self)
    }
}
