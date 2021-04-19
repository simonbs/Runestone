//
//  LineFragmentView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

final class LineFragmentView: UIView {
    var renderer: LineFragmentRenderer? {
        didSet {
            if renderer !== oldValue {
                setNeedsDisplay()
            }
        }
    }

    override var frame: CGRect {
        didSet {
            if frame.size != oldValue.size {
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
            renderer?.draw(to: context)
        }
    }
}
