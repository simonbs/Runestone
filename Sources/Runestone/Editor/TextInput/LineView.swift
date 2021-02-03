//
//  LineView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

final class LineView: UIView {
    var textLayer: CATextLayer {
        return layer as! CATextLayer
    }

    override class var layerClass: AnyClass {
        return CATextLayer.self
    }

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.isWrapped = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
