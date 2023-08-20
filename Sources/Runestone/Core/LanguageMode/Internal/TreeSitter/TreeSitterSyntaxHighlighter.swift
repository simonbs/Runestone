import Combine
import Foundation

final class TreeSitterSyntaxHighlighter: SyntaxHighlighter {
    let theme: CurrentValueSubject<Theme, Never>
    let operationQueue: OperationQueue
    var inlinePredictionRange: NSRange?
    
    private let stringView: CurrentValueSubject<StringView, Never>
    private let languageMode: TreeSitterInternalLanguageMode

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        languageMode: TreeSitterInternalLanguageMode,
        theme: CurrentValueSubject<Theme, Never>,
        operationQueue: OperationQueue
    ) {
        self.stringView = stringView
        self.languageMode = languageMode
        self.theme = theme
        self.operationQueue = operationQueue
    }

    func performHeavyBackgroundSafeWork(with input: SyntaxHighlighterInput) -> [TreeSitterCapture] {
        languageMode.captures(in: input.byteRange)
    }

    func performWorkRequiringMainQueue(with input: SyntaxHighlighterInput, using result: [TreeSitterCapture]) {
        let tokens = tokens(for: result, localTo: input.byteRange)
        setAttributes(for: tokens, on: input.attributedString)
    }
}

private extension TreeSitterSyntaxHighlighter {
    private func setAttributes(for tokens: [TreeSitterSyntaxHighlightToken], on attributedString: NSMutableAttributedString) {
        attributedString.beginEditing()
        for token in tokens {
            var attributes: [NSAttributedString.Key: Any] = [:]
            if let foregroundColor = token.textColor {
                attributes[.foregroundColor] = foregroundColor
            }
            if let shadow = token.shadow {
                attributes[.shadow] = shadow
            }
            if token.fontTraits.contains(.bold) {
                attributedString.addAttribute(.isBold, value: true, range: token.range)
            }
            if token.fontTraits.contains(.italic) {
                attributedString.addAttribute(.isItalic, value: true, range: token.range)
            }
            var symbolicTraits: MultiPlatformFontDescriptor.SymbolicTraits = []
            if let isBold = attributedString.attribute(.isBold, at: token.range.location, effectiveRange: nil) as? Bool, isBold {
                #if os(iOS)
                symbolicTraits.insert(.traitBold)
                #else
                symbolicTraits.insert(.bold)
                #endif
            }
            if let isItalic = attributedString.attribute(.isItalic, at: token.range.location, effectiveRange: nil) as? Bool, isItalic {
                #if os(iOS)
                symbolicTraits.insert(.traitItalic)
                #else
                symbolicTraits.insert(.italic)
                #endif
            }
            let currentFont = attributedString.attribute(.font, at: token.range.location, effectiveRange: nil) as? MultiPlatformFont
            let baseFont = token.font ?? theme.value.font
            let newFont: MultiPlatformFont
            if !symbolicTraits.isEmpty {
                newFont = baseFont.withSymbolicTraits(symbolicTraits) ?? baseFont
            } else {
                newFont = baseFont
            }
            if newFont != currentFont {
                attributes[.font] = newFont
            }
            if !attributes.isEmpty {
                attributedString.addAttributes(attributes, range: token.range)
            }
        }
        attributedString.endEditing()
    }

    private func tokens(for captures: [TreeSitterCapture], localTo localRange: ByteRange) -> [TreeSitterSyntaxHighlightToken] {
        var tokens: [TreeSitterSyntaxHighlightToken] = []
        for capture in captures where capture.byteRange.overlaps(localRange) {
            // We highlight each line separately but a capture may extend beyond a line,
            // e.g. an unterminated string, so we need to cap the start and end location
            // to ensure it's within the line.
            let cappedStartByte = max(capture.byteRange.lowerBound, localRange.lowerBound)
            let cappedEndByte = min(capture.byteRange.upperBound, localRange.upperBound)
            let length = cappedEndByte - cappedStartByte
            let cappedRange = ByteRange(location: cappedStartByte - localRange.lowerBound, length: length)
            if !cappedRange.isEmpty {
                let token = token(from: capture, in: cappedRange)
                if !token.isEmpty {
                    tokens.append(token)
                }
            }
        }
        return tokens
    }
}

private extension TreeSitterSyntaxHighlighter {
    private func token(from capture: TreeSitterCapture, in byteRange: ByteRange) -> TreeSitterSyntaxHighlightToken {
        let range = NSRange(byteRange)
        let textColor = theme.value.textColor(for: capture.name)
        let shadow = theme.value.shadow(for: capture.name)
        let font = theme.value.font(for: capture.name)
        let fontTraits = theme.value.fontTraits(for: capture.name)
        return TreeSitterSyntaxHighlightToken(range: range, textColor: textColor, shadow: shadow, font: font, fontTraits: fontTraits)
    }
}

private extension MultiPlatformFont {
    func withSymbolicTraits(_ symbolicTraits: MultiPlatformFontDescriptor.SymbolicTraits) -> MultiPlatformFont? {
        #if os(iOS)
        if let newFontDescriptor = fontDescriptor.withSymbolicTraits(symbolicTraits) {
            return MultiPlatformFont(descriptor: newFontDescriptor, size: pointSize)
        } else {
            return nil
        }
        #else
        let newFontDescriptor = fontDescriptor.withSymbolicTraits(symbolicTraits)
        return MultiPlatformFont(descriptor: newFontDescriptor, size: pointSize)
        #endif
    }
}
