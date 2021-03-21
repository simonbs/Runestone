//
//  PageGuideController.swift
//  
//
//  Created by Simon on 21/03/2021.
//

import UIKit

final class PageGuideView: UIView {
    var hairlineWidth: CGFloat = 1 / UIScreen.main.scale {
        didSet {
            if hairlineWidth != oldValue {
                setNeedsLayout()
            }
        }
    }
    var hairlineColor: UIColor? {
        get {
            return hairlineView.backgroundColor
        }
        set {
            hairlineView.backgroundColor = newValue
        }
    }

    private let hairlineView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(hairlineView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hairlineView.frame = CGRect(x: 0, y: 0, width: hairlineWidth, height: bounds.height)
    }
}

final class PageGuideController {
    let guideView = PageGuideView()
    var font: UIFont = .systemFont(ofSize: 14) {
        didSet {
            if font != oldValue {
                _columnOffset = nil
            }
        }
    }
    var column = 120 {
        didSet {
            if column != oldValue {
                _columnOffset = nil
            }
        }
    }
    var columnOffset: CGFloat {
        if let columnOffset = _columnOffset {
            return columnOffset
        } else {
            // Measure the width of a single character and multiply it by the pageGuideColumn.
            let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
            let options: NSStringDrawingOptions = [.usesFontLeading, .usesLineFragmentOrigin]
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let bounds = " ".boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
            let columnOffset = round(bounds.size.width * CGFloat(column))
            _columnOffset = columnOffset
            return columnOffset
        }
    }

    private var _columnOffset: CGFloat?
}
