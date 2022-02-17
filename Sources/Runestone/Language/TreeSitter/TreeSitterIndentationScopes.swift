import Foundation

public final class TreeSitterIndentationScopes {
    public let indent: [String]
    public let inheritIndent: [String]
    public let outdent: [String]
    public let indentationDenotesBlocks: Bool

    public init(indent: [String] = [],
                inheritIndent: [String] = [],
                outdent: [String] = [],
                whitespaceDenotesBlocks: Bool = false) {
        self.indent = indent
        self.inheritIndent = inheritIndent
        self.outdent = outdent
        self.indentationDenotesBlocks = whitespaceDenotesBlocks
    }
}

extension TreeSitterIndentationScopes: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[TreeSitterIndentationScopes indent=\(indent)"
        + " inheritIndent=\(inheritIndent)"
        + " outdent=\(outdent)"
        + " indentationDenotesBlocks=\(indentationDenotesBlocks)]"
    }
}
