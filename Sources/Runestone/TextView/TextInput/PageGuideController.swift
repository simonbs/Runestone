//
//  PageGuideController.swift
//  
//
//  Created by Simon on 21/03/2021.
//

import UIKit

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
