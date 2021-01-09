//
//  EditorTextLayerFrameStore.swift
//  
//
//  Created by Simon Støvring on 08/01/2021.
//

import Foundation
import CoreGraphics

protocol EditorTextLayerFrameStoreDelegate: AnyObject {
    func editorTextLayerFrameStore(_ frameStore: EditorTextLayerFrameStore, estimatedHeightForItemAt index: Int) -> CGFloat
    func numberOfLines(in frameStore: EditorTextLayerFrameStore) -> Int
}

final class EditorTextLayerFrameStore {
    weak var delegate: EditorTextLayerFrameStoreDelegate?

    var width: CGFloat = 0
    var estimatedLineHeight: CGFloat = 10
    var contentSize: CGSize {
        return CGSize(width: width, height: contentHeight)
    }

    private var cachedHeights: [Int: CGFloat] = [:]
    private var cachedVerticalOffsets: [Int: CGFloat] = [:]
    private var contentHeight: CGFloat = 0
    private var numberOfLines: Int {
        return currentDelegate.numberOfLines(in: self)
    }
    private var currentDelegate: EditorTextLayerFrameStoreDelegate {
        guard let delegate = delegate else {
            preconditionFailure("`delegate` of \(type(of: self)) should not be `nil`")
        }
        return delegate
    }

    func reset() {
        cachedHeights = [:]
        cachedVerticalOffsets = [:]
        contentHeight = estimatedLineHeight * CGFloat(numberOfLines)
    }

    func frameForLine(at index: Int) -> CGRect {
        let itemHeight = heightForLine(at: index)
        let yPosition = verticalOffsetForLine(at: index)
        return CGRect(x: 0, y: yPosition, width: width, height: itemHeight)
    }

    @discardableResult
    func setHeight(to height: CGFloat, forLineAt lineIndex: Int) -> Bool {
        guard height != heightForLine(at: lineIndex) else {
            return false
        }
        let previousHeight = heightForLine(at: lineIndex)
        let heightDiff = height - previousHeight
        cachedHeights[lineIndex] = height
        for (idx, _) in cachedHeights.enumerated() where idx > lineIndex {
            if let verticalOffset = cachedVerticalOffsets[idx] {
                cachedVerticalOffsets[idx] = verticalOffset + heightDiff
            }
        }
        contentHeight += heightDiff
        return true
    }
}

private extension EditorTextLayerFrameStore {
    private func verticalOffsetForLine(at lineIndex: Int) -> CGFloat {
        let previousIndex = lineIndex - 1
        let previousHeight = cachedHeights[previousIndex] ?? estimatedLineHeight
        if let previousVerticalOffset = cachedVerticalOffsets[previousIndex] {
            let verticalOffset = previousVerticalOffset + previousHeight
            cachedVerticalOffsets[lineIndex] = verticalOffset
            return verticalOffset
        } else {
            let verticalOffset = (0 ..< lineIndex).reduce(0) { current, index in
                return current + heightForLine(at: index)
            }
            cachedVerticalOffsets[lineIndex] = verticalOffset
            return verticalOffset
        }
    }

    private func heightForLine(at lineIndex: Int) -> CGFloat {
        return cachedHeights[lineIndex] ?? estimatedLineHeight
    }
}
