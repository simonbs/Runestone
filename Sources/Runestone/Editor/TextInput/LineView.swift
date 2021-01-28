//
//  LineView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

final class LineView: UIView {
    var textRenderer: TextRenderer? {
        didSet {
            if textRenderer !== oldValue {
                textRenderer?.frame = frame
                setNeedsDisplay()
            }
        }
    }
    override var frame: CGRect {
        didSet {
            if frame != oldValue {
                textRenderer?.frame = frame
            }
        }
    }

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if let context = UIGraphicsGetCurrentContext() {
            textRenderer?.draw(in: context)
        }
    }
}
