//
//  LineFragmentView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
//

import UIKit

final class LineFragmentView: UIImageView {
    var renderer: LineFragmentRenderer? {
        didSet {
            if renderer !== oldValue {
                updateImage()
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

    override func layoutSubviews() {
        super.layoutSubviews()
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
            image = renderer?.renderImage(ofSize: bounds.size)
        }
    }
}
