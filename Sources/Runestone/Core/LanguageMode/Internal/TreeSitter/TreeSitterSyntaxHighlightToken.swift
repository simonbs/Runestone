#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

final class TreeSitterSyntaxHighlightToken {
    let range: NSRange
    let textColor: MultiPlatformColor?
    let shadow: NSShadow?
    let font: MultiPlatformFont?
    let fontTraits: FontTraits
    var isEmpty: Bool {
        range.length == 0 || (textColor == nil && font == nil && shadow == nil)
    }

    init(range: NSRange, textColor: MultiPlatformColor?, shadow: NSShadow?, font: MultiPlatformFont?, fontTraits: FontTraits) {
        self.range = range
        self.textColor = textColor
        self.shadow = shadow
        self.font = font
        self.fontTraits = fontTraits
    }
}

extension TreeSitterSyntaxHighlightToken: Equatable {
    static func == (lhs: TreeSitterSyntaxHighlightToken, rhs: TreeSitterSyntaxHighlightToken) -> Bool {
        lhs.range == rhs.range && lhs.textColor == rhs.textColor && lhs.font == rhs.font
    }
}

extension TreeSitterSyntaxHighlightToken {
    static func locationSort(_ lhs: TreeSitterSyntaxHighlightToken, _ rhs: TreeSitterSyntaxHighlightToken) -> Bool {
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        } else {
            return lhs.range.length < rhs.range.length
        }
    }
}

extension TreeSitterSyntaxHighlightToken: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterSyntaxHighlightToken: \(range.location) - \(range.length)]"
    }
}
