//
//  TextPreview.swift
//  
//
//  Created by Simon on 31/08/2021.
//

import Foundation

public protocol TextPreviewDelegate: AnyObject {
    func textPreviewDidUpdateAttributedString(_ provider: TextPreview)
}

public final class TextPreview {
    public weak var delegate: TextPreviewDelegate?
    public let needleRange: NSRange
    public let previewRange: NSRange
    public let needleInPreviewRange: NSRange
    public private(set) var attributedString: NSAttributedString?

    private let lineControllers: [LineController]

    init(needleRange: NSRange, previewRange: NSRange, needleInPreviewRange: NSRange, lineControllers: [LineController]) {
        self.needleRange = needleRange
        self.previewRange = previewRange
        self.needleInPreviewRange = needleInPreviewRange
        self.lineControllers = lineControllers
        for lineController in lineControllers {
            lineController.addObserver(self)
        }
    }

    public func prepare() {
        forEachRangeInLineController { lineController, range in
            lineController.prepareToDisplayString(toLocation: range.upperBound, syntaxHighlightAsynchronously: true)
        }
        updateAttributedString()
    }

    public func invalidateSyntaxHighlighting() {
        for lineController in lineControllers {
            lineController.invalidateSyntaxHighlighting()
        }
    }

    public func cancelSyntaxHighlighting() {
        for lineController in lineControllers {
            lineController.cancelSyntaxHighlighting()
        }
    }
}

private extension TextPreview {
    private func updateAttributedString() {
        let resultingAttributedString = NSMutableAttributedString()
        forEachRangeInLineController { lineController, range in
            if let attributedString = lineController.attributedString, range.upperBound < attributedString.length {
                let substring = attributedString.attributedSubstring(from: range)
                resultingAttributedString.append(substring)
            }
        }
        attributedString = resultingAttributedString
    }

    private func forEachRangeInLineController(_ handler: (LineController, NSRange) -> Void) {
        var remainingLength = previewRange.length
        for lineController in lineControllers {
            let lineLocation = lineController.line.location
            let lineLength = lineController.line.data.totalLength
            let location = max(previewRange.location - lineLocation, 0)
            let length = min(remainingLength, lineLength)
            let range = NSRange(location: location, length: length)
            remainingLength -= length
            handler(lineController, range)
        }
    }
}

extension TextPreview: LineControllerAttributedStringObserver {
    func lineControllerDidUpdateAttributedString(_ lineController: LineController) {
        updateAttributedString()
        delegate?.textPreviewDidUpdateAttributedString(self)
    }
}
