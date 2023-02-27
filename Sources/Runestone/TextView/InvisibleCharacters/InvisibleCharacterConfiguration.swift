#if os(macOS)
import AppKit
#endif
import CoreGraphics
#if os(iOS)
import UIKit
#endif

final class InvisibleCharacterConfiguration {
    var font: MultiPlatformFont = .systemFont(ofSize: 12) {
        didSet {
            if font != oldValue {
                cachedLineBreakSymbolSize = nil
                cachedSoftLineBreakSymbolSize = nil
            }
        }
    }
    var textColor: MultiPlatformColor = .label
    var showTabs = false
    var showSpaces = false
    var showNonBreakingSpaces = false
    var showLineBreaks = false {
        didSet {
            if showLineBreaks != oldValue {
                cachedLineBreakSymbolSize = nil
            }
        }
    }
    var showSoftLineBreaks = false {
        didSet {
            if showSoftLineBreaks != oldValue {
                cachedSoftLineBreakSymbolSize = nil
            }
        }
    }
    var tabSymbol = "\u{25b8}"
    var spaceSymbol = "\u{00b7}"
    var nonBreakingSpaceSymbol = "\u{00b7}"
    var lineBreakSymbol = "\u{00ac}" {
        didSet {
            if lineBreakSymbol != oldValue {
                cachedLineBreakSymbolSize = nil
            }
        }
    }
    var softLineBreakSymbol = "\u{00ac}" {
        didSet {
            if softLineBreakSymbol != oldValue {
                cachedSoftLineBreakSymbolSize = nil
            }
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

    private var lineBreakSymbolSize: CGSize {
        if let cachedLineBreakSymbolSize {
            return cachedLineBreakSymbolSize
        } else if showLineBreaks {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let lineBreakSymbolSize = lineBreakSymbol.size(withAttributes: attrs)
            cachedLineBreakSymbolSize = lineBreakSymbolSize
            return lineBreakSymbolSize
        } else {
            return .zero
        }
    }
    private var softLineBreakSymbolSize: CGSize {
        if let cachedSoftLineBreakSymbolSize {
            return cachedSoftLineBreakSymbolSize
        } else if showSoftLineBreaks {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let softLineBreakSymbolSize = softLineBreakSymbol.size(withAttributes: attrs)
            cachedSoftLineBreakSymbolSize = softLineBreakSymbolSize
            return softLineBreakSymbolSize
        } else {
            return .zero
        }
    }

    private var cachedLineBreakSymbolSize: CGSize?
    private var cachedSoftLineBreakSymbolSize: CGSize?
}
