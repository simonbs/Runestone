//
//  LineFragmentView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

protocol LineFragmentViewDelegate: AnyObject {
    func lineFragmentView(_ lineFragmentView: LineFragmentView, shouldDrawTo context: CGContext)
}

final class LineFragmentView: UIView {
    weak var delegate: LineFragmentViewDelegate?

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
            delegate?.lineFragmentView(self, shouldDrawTo: context)
        }
    }
}
