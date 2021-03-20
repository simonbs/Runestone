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
    let line: DocumentLineNode
    var lineFragment: LineFragment {
        didSet {
            if lineFragment !== oldValue {
                renderer.lineFragment = lineFragment
                lineFragmentView?.setNeedsDisplay()
            }
        }
    }
    weak var delegate: LineFragmentControllerDelegate?
    weak var lineFragmentView: LineFragmentView? {
        didSet {
            if lineFragmentView != oldValue {
                lineFragmentView?.delegate = self
            }
        }
    }

    private let renderer: LineFragmentRenderer

    init(line: DocumentLineNode, lineFragment: LineFragment) {
        self.line = line
        self.lineFragment = lineFragment
        self.renderer = LineFragmentRenderer(lineFragment: lineFragment)
        self.renderer.delegate = self
    }

//    func didEndDisplaying() {
//        lineFragmentView?.delegate = nil
//        lineFragmentView = nil
//    }
}

// MARK: - LineFragme ntRendererDelegate
extension LineFragmentController: LineFragmentRendererDelegate {
    func string(in lineFragmentRenderer: LineFragmentRenderer) -> String? {
        return delegate?.string(in: self)
    }
}

// MARK: - LineViewDelegate
extension LineFragmentController: LineFragmentViewDelegate {
    func lineFragmentView(_ lineFragmentView: LineFragmentView, shouldDrawTo context: CGContext) {
        renderer.draw(to: context)
    }
}
