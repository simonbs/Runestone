#if canImport(AppKit)
import AppKit
import RunestoneSyntax

/// AppKit attributes applied to a semantic Tree-sitter capture.
///
/// Nil values preserve the corresponding document attribute. Capture names
/// fall back through dotted parents, so a `function.method` capture uses a
/// `function` style when no exact style exists.
public struct RunestoneAppKitSyntaxStyle {
    public var foregroundColor: NSColor?
    public var backgroundColor: NSColor?
    public var font: NSFont?

    public init(foregroundColor: NSColor? = nil, backgroundColor: NSColor? = nil,
                font: NSFont? = nil) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.font = font
    }
}

/// A language parser and its AppKit-only semantic appearance.
///
/// Parsing stays in `RunestoneSyntax`; this value only maps semantic capture
/// names onto presentation attributes. It never changes canonical text or
/// participates in input and undo transactions.
public struct RunestoneAppKitSyntaxConfiguration {
    public let highlighter: RunestoneSyntaxHighlighting
    public var styles: [String: RunestoneAppKitSyntaxStyle]

    public init(highlighter: RunestoneSyntaxHighlighting,
                styles: [String: RunestoneAppKitSyntaxStyle]) {
        self.highlighter = highlighter
        self.styles = styles
    }

    func style(for captureName: String) -> RunestoneAppKitSyntaxStyle? {
        var candidate = captureName
        while true {
            if let style = styles[candidate] { return style }
            guard let separator = candidate.lastIndex(of: ".") else { return nil }
            candidate = String(candidate[..<separator])
        }
    }
}
#endif
