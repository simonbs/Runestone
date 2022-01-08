//
//  LineFragmentController.swift
//  
//
//  Created by Simon on 20/03/2021.
//

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
                lineFragmentView?.invalidateAndUpdateImage()
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
    var highlightedRanges: [HighlightedRange] {
        get {
            return renderer.highlightedRanges
        }
        set {
            if newValue != renderer.highlightedRanges {
                renderer.highlightedRanges = newValue
                lineFragmentView?.invalidateAndUpdateImage()
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
