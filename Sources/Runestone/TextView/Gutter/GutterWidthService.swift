import UIKit

final class GutterWidthService {
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                _lineNumberWidth = nil
            }
        }
    }
    var font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular) {
        didSet {
            if font != oldValue {
                _lineNumberWidth = nil
            }
        }
    }
    var showLineNumbers = false
    var gutterLeadingPadding: CGFloat = 0
    var gutterTrailingPadding: CGFloat = 0
    var gutterWidth: CGFloat {
        if showLineNumbers {
            return lineNumberWidth + gutterLeadingPadding + gutterTrailingPadding
        } else {
            return 0
        }
    }
    var lineNumberWidth: CGFloat {
        let lineCount = lineManager.lineCount
        let hasLineCountChanged = lineCount != previousLineCount
        let hasFontChanged = font != previousFont
        if let lineNumberWidth = _lineNumberWidth, !hasLineCountChanged && !hasFontChanged {
            return lineNumberWidth
        } else {
            let lineNumberWidth = computeLineNumberWidth()
            _lineNumberWidth = lineNumberWidth
            previousFont = font
            previousLineCount = lineManager.lineCount
            return lineNumberWidth
        }
    }

    private var _lineNumberWidth: CGFloat?
    private var previousLineCount = 0
    private var previousFont: UIFont?

    init(lineManager: LineManager) {
        self.lineManager = lineManager
    }

    func invalidateLineNumberWidth() {
        _lineNumberWidth = nil
    }
}

private extension GutterWidthService {
    private func computeLineNumberWidth() -> CGFloat {
        let characterCount = "\(lineManager.lineCount)".count
        let wideLineNumberString = String(repeating: "8", count: characterCount)
        let wideLineNumberNSString = wideLineNumberString as NSString
        let size = wideLineNumberNSString.size(withAttributes: [.font: font])
        return ceil(size.width)
//        if width != oldLineNumberWidth {
//            delegate?.layoutManagerDidChangeGutterWidth(self)
//            _textContentWidth = nil
//            delegate?.layoutManagerDidInvalidateContentSize(self)
//        }
    }
}
