import UIKit

final class InvisibleCharacterConfiguration {
    var font: UIFont = .systemFont(ofSize: 12) {
        didSet {
            if font != oldValue {
                _lineBreakSymbolSize = nil
                _softLineBreakSymbolSize = nil
            }
        }
    }
    var textColor: UIColor = .label
    var showTabs = false
    var showSpaces = false
    var showNonBreakingSpaces = false
    var showLineBreaks = false {
        didSet {
            if showLineBreaks != oldValue {
                _lineBreakSymbolSize = nil
            }
        }
    }
    var showSoftLineBreaks = false {
        didSet {
            if showSoftLineBreaks != oldValue {
                _softLineBreakSymbolSize = nil
            }
        }
    }
    var tabSymbol = "\u{25b8}"
    var spaceSymbol = "\u{00b7}"
    var nonBreakingSpaceSymbol = "\u{00b7}"
    var lineBreakSymbol = "\u{00ac}" {
        didSet {
            if lineBreakSymbol != oldValue {
                _lineBreakSymbolSize = nil
            }
        }
    }
    var softLineBreakSymbol = "\u{00ac}" {
        didSet {
            if softLineBreakSymbol != oldValue {
                _softLineBreakSymbolSize = nil
            }
        }
    }
    var lineBreakSymbolSize: CGSize {
        if let lineBreakSymbolSize = _lineBreakSymbolSize {
            return lineBreakSymbolSize
        } else if showLineBreaks {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let lineBreakSymbolSize = lineBreakSymbol.size(withAttributes: attrs)
            _lineBreakSymbolSize = lineBreakSymbolSize
            return lineBreakSymbolSize
        } else {
            return .zero
        }
    }
    var softLineBreakSymbolSize: CGSize {
        if let softLineBreakSymbolSize = _softLineBreakSymbolSize {
            return softLineBreakSymbolSize
        } else if showSoftLineBreaks {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let softLineBreakSymbolSize = softLineBreakSymbol.size(withAttributes: attrs)
            _softLineBreakSymbolSize = softLineBreakSymbolSize
            return softLineBreakSymbolSize
        } else {
            return .zero
        }
    }
    var maximumLineBreakSymbolWidth: CGFloat {
        if showLineBreaks && showSoftLineBreaks {
            return max(lineBreakSymbolSize.width, softLineBreakSymbolSize.width)
        } else if showLineBreaks {
            return lineBreakSymbolSize.width
        } else if showSoftLineBreaks {
            return softLineBreakSymbolSize.width
        } else {
            return 0
        }
    }

    private var _lineBreakSymbolSize: CGSize?
    private var _softLineBreakSymbolSize: CGSize?
}
