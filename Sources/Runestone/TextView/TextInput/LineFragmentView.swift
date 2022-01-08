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
                updateImage()
            }
        }
    }

    private let imageView: UIImageView = {
        let this = UIImageView()
        this.translatesAutoresizingMaskIntoConstraints = false
        return this
    }()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        updateImage()
    }

    func invalidateAndUpdateImage() {
        renderer?.invalidateCachedImage()
        if window != nil {
            updateImage()
        }
    }
}

private extension LineFragmentView {
    private func updateImage() {
        if bounds.size != .zero {
            imageView.image = renderer?.renderImage(ofSize: bounds.size)
        }
    }
}
