import UIKit

enum TreeSitterSyntaxHighlighterError: LocalizedError {
    case cancelled
    case operationDeallocated

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation was cancelled"
        case .operationDeallocated:
            return "The operation was deallocated"
        }
    }
}

final class TreeSitterSyntaxHighlighter: LineSyntaxHighlighter {
    var theme: Theme = DefaultTheme.shared {
        didSet { cancel() }
    }
    var kern: CGFloat = 0
    var canHighlight: Bool {
        languageMode.canHighlight
    }

    private let stringView: StringView
    private let languageMode: TreeSitterInternalLanguageMode
    private let operationQueue: OperationQueue
    private var currentOperation: Operation?

    init(stringView: StringView, languageMode: TreeSitterInternalLanguageMode, operationQueue: OperationQueue) {
        self.stringView = stringView
        self.languageMode = languageMode
        self.operationQueue = operationQueue
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {
        cancel()
        let captures = languageMode.captures(in: input.byteRange).map(TreeSitterSyntaxCapture.init)
        let highlights = TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: input.byteRange)
        let tokens = highlights.map(token(from:)).filter { !$0.isEmpty }
        setAttributes(for: tokens, on: input.attributedString)
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        cancel()
        let snapshot = languageMode.makeHighlightSnapshot()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let operation = operation, let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(TreeSitterSyntaxHighlighterError.operationDeallocated))
                }
                return
            }
            guard !operation.isCancelled else {
                DispatchQueue.main.async {
                    completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                }
                return
            }
            let captures = snapshot.captures(in: input.byteRange) { operation.isCancelled }
                .map(TreeSitterSyntaxCapture.init)
            if !operation.isCancelled {
                DispatchQueue.main.async {
                    defer {
                        if self.currentOperation === operation { self.currentOperation = nil }
                    }
                    if self.currentOperation === operation && !operation.isCancelled && input.isValid() {
                        let highlights = TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: input.byteRange)
                        let tokens = highlights.map(self.token(from:)).filter { !$0.isEmpty }
                        guard self.currentOperation === operation && !operation.isCancelled && input.isValid() else {
                            completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                            return
                        }
                        let result = withExtendedLifetime(snapshot) {
                            self.setAttributes(for: tokens, on: input.attributedString)
                        }
                        completion(.success(result))
                    } else {
                        completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if self.currentOperation === operation { self.currentOperation = nil }
                    completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                }
            }
        }
        currentOperation = operation
        operationQueue.addOperation(operation)
    }

    func cancel() {
        currentOperation?.cancel()
        currentOperation = nil
    }
}

private extension TreeSitterSyntaxHighlighter {
    private struct FontRun: Equatable {
        let range: NSRange
        let font: UIFont?
    }

    private func fontRuns(in string: NSAttributedString) -> [FontRun] {
        var runs: [FontRun] = []
        string.enumerateAttribute(.font, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            runs.append(FontRun(range: range, font: value as? UIFont))
        }
        return runs
    }

    @discardableResult
    private func setAttributes(for tokens: [TreeSitterSyntaxHighlightToken], on attributedString: NSMutableAttributedString)
    -> LineSyntaxHiglighterSetAttributesResult {
        // Font is the only geometry attribute written by syntax highlighting. Compare
        // final runs: overlapping captures can change a font and then restore it.
        let previousFonts = fontRuns(in: attributedString)
        attributedString.beginEditing()
        for token in tokens {
            if let style = token.completeStyle {
                apply(style, to: attributedString, in: token.range)
                continue
            }
            applyIndividualAttributes(for: token, to: attributedString)
        }
        attributedString.endEditing()
        return .init(isSizingInvalid: previousFonts != fontRuns(in: attributedString))
    }

    private func applyIndividualAttributes(for token: TreeSitterSyntaxHighlightToken, to attributedString: NSMutableAttributedString) {
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
        var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
        if let isBold = attributedString.attribute(.isBold, at: token.range.location, effectiveRange: nil) as? Bool, isBold {
            symbolicTraits.insert(.traitBold)
        }
        if let isItalic = attributedString.attribute(.isItalic, at: token.range.location, effectiveRange: nil) as? Bool, isItalic {
            symbolicTraits.insert(.traitItalic)
        }
        let currentFont = attributedString.attribute(.font, at: token.range.location, effectiveRange: nil) as? UIFont
        let baseFont = token.font ?? theme.font
        let newFont: UIFont
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

    private func apply(_ style: HighlightStyle, to attributedString: NSMutableAttributedString, in range: NSRange) {
        // Complete styles must also reset our bookkeeping for subsequent captures that
        // use the individual callbacks, otherwise an outer trait can reappear later.
        let font = style.font ?? theme.font
        let traits = font.fontDescriptor.symbolicTraits
        attributedString.addAttributes([
            .foregroundColor: style.textColor ?? theme.textColor,
            .font: font,
            .isBold: traits.contains(.traitBold),
            .isItalic: traits.contains(.traitItalic)
        ], range: range)
        attributedString.removeAttribute(.backgroundColor, range: range)
        attributedString.removeAttribute(.shadow, range: range)
        if let backgroundColor = style.backgroundColor {
            attributedString.addAttribute(.backgroundColor, value: backgroundColor, range: range)
        }
        if let shadow = style.shadow {
            attributedString.addAttribute(.shadow, value: shadow, range: range)
        }
    }

    private func token(from highlight: SyntaxHighlight) -> TreeSitterSyntaxHighlightToken {
        if let style = theme.highlightStyle(for: highlight.name) {
            return TreeSitterSyntaxHighlightToken(
                range: highlight.range, textColor: nil, shadow: nil, font: nil, fontTraits: [], completeStyle: style)
        }
        let textColor = theme.textColor(for: highlight.name)
        let shadow = theme.shadow(for: highlight.name)
        let font = theme.font(for: highlight.name)
        let fontTraits = theme.fontTraits(for: highlight.name)
        return TreeSitterSyntaxHighlightToken(
            range: highlight.range, textColor: textColor, shadow: shadow, font: font, fontTraits: fontTraits)
    }
}

private extension UIFont {
    func withSymbolicTraits(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        if let newFontDescriptor = fontDescriptor.withSymbolicTraits(symbolicTraits) {
            return UIFont(descriptor: newFontDescriptor, size: pointSize)
        } else {
            return nil
        }
    }
}
