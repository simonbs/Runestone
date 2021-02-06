//
//  LineView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

protocol LineViewDelegate: AnyObject {
    func lineView(_ lineView: LineView, shouldDrawTo context: CGContext)
}

final class LineView: UIView {
    weak var delegate: LineViewDelegate?

    override var frame: CGRect {
        didSet {
            if frame != oldValue {
                setNeedsDisplay()
            }
        }
    }
    
    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if let context = UIGraphicsGetCurrentContext() {
            delegate?.lineView(self, shouldDrawTo: context)
        }
    }
}
