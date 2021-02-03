//
//  LineController.swift
//  
//
//  Created by Simon Støvring on 02/02/2021.
//

import CoreGraphics
import Foundation

protocol LineControllerDelegate: AnyObject {
    func string(in lineController: LineController) -> String
}

final class LineController {
    weak var delegate: LineControllerDelegate?
    let line: DocumentLineNode
    weak var lineView: LineView?
    var lineViewFrame: CGRect = .zero {
        didSet {
            if lineViewFrame != oldValue {
                lineView?.lineController?.lineView = nil
                lineView?.lineController = self
                lineView?.frame = lineViewFrame
            }
        }
    }
    var defaultLineHeight: CGFloat = 12 {
        didSet {
            if defaultLineHeight != oldValue {
                textInputProxy.defaultLineHeight = defaultLineHeight
            }
        }
    }
    var preferredSize: CGSize {
        if let preferredSize = typesetter.preferredSize {
            return preferredSize
        } else {
            return CGSize(width: 0, height: defaultLineHeight)
        }
    }

    private let typesetter = LineTypesetter()
    private let textInputProxy: LineTextInputProxy
    private var isTypesetterInvalid = true
    private var attributedString: CFAttributedString?

    init(line: DocumentLineNode) {
        self.line = line
        self.textInputProxy = LineTextInputProxy(lineTypesetter: typesetter)
    }

    func willDisplay() {
        updateTypesetterIfNecessary()
        lineView?.textLayer.string = attributedString
        lineView?.frame = lineViewFrame
    }

    func updateTypesetterIfNecessary() {
        if isTypesetterInvalid {
            updateAttributedString()
            if let attributedString = attributedString {
                typesetter.typeset(attributedString)
            }
            isTypesetterInvalid = false
        }
    }
}

private extension LineController {
    private func updateAttributedString() {
        let string = delegate!.string(in: self)
        attributedString = CFAttributedStringCreate(kCFAllocatorDefault, string as CFString, nil)
    }
}

// MARK: - UITextInput
extension LineController {
    func caretRect(atIndex index: Int) -> CGRect {
        return textInputProxy.caretRect(atIndex: index)
    }

    func selectionRects(in range: NSRange) -> [TypesetLineSelectionRect] {
        return textInputProxy.selectionRects(in: range)
    }

    func firstRect(for range: NSRange) -> CGRect {
        return textInputProxy.firstRect(for: range)
    }

    func closestIndex(to point: CGPoint) -> Int {
        return textInputProxy.closestIndex(to: point)
    }
}
