//
//  LineView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

protocol LineViewDelegate: AnyObject {
    func lineView(_ lineView: LineView, stringIn range: NSRange) -> String
}

final class LineView: UIView {
    weak var delegate: LineViewDelegate?
    var textRenderer: TextRenderer? {
        didSet {
            if textRenderer !== oldValue {
                textRenderer?.delegate = self
                textRenderer?.frame = frame
                textLayer.string = textRenderer?.attributedString
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

    private var textLayer: CATextLayer {
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    override func layoutSubviews() {
//        super.layoutSubviews()
//        textLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
//    }

//    override func draw(_ rect: CGRect) {
//        super.draw(rect)
//        if let context = UIGraphicsGetCurrentContext() {
//            textRenderer?.draw(in: context)
//        }
//    }
}

extension LineView: TextRendererDelegate {
    func textRenderer(_ textRenderer: TextRenderer, stringIn range: NSRange) -> String {
        return delegate!.lineView(self, stringIn: range)
    }

    func textRendererDidPrepareToDraw(_ textRenderer: TextRenderer) {
        textLayer.string = textRenderer.attributedString
    }

    func textRendererDidUpdateSyntaxHighlighting(_ textRenderer: TextRenderer) {
        textLayer.string = textRenderer.attributedString
    }
}
