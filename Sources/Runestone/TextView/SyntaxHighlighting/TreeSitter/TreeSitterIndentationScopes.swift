import Foundation

/// Indentation rules to be used with a `TreeSitterLanguage`.
///
/// This approach for doing indentation will likely be deprecated in the near future and replaced with an approach that uses Tree-sitter queries.
///
/// It is not advised to start using this API until it has been revised.
public final class TreeSitterIndentationScopes {
    /// Node types adding a level of indentation.
    ///
    /// Examples of this typically include if-statements and loops.
    public let indent: [String]
    /// Inherit indentation from a parent node in the syntax tree.
    ///
    ///    An example of this includes the "elsif" and "else" nodes in Ruby.
    ///    ```
    ///    if myBool
    ///       # ...
    ///    elseif myBool2|
    ///       # ...
    ///    else|
    ///       # ...
    ///    end
    ///    ```
    ///
    ///    Inserting a line break where one of the pipes are placed shouldn't increase the indent level but instead keep the indent level starting at the "if" node. This is needed because "elseif" and "else" are children of the "if" node.
    public let inheritIndent: [String]
    /// Node types removing a level of indentation.
    ///
    /// Examples of this typically include closing brackets.
    public let outdent: [String]
    /// Enable to start searching for nodes increasing indentation from the deepest node in the syntax tree.
    ///
    /// This set to `true` in languages where whitespace denotes a block. This includes Python and YAML. In those languages we cannot rely solely on the caret location when indenting.
    ///
    /// Consider the following Python code:
    ///
    /// ```
    /// def helloWorld():|
    /// ```
    ///
    /// The caret is placed at the pipe. Pressing enter will insert a line break in the `module` scope. This is the outermost scope and it does not indent. Instead we find the deepest child that contains the caret. That happens to be a `block` which does in fact indent.
    public let whitespaceDenotesBlocks: Bool

    /// Creates indentation rules.
    /// - Parameters:
    ///   - indent: Node types adding a level of indentation.
    ///   - inheritIndent: Inherit indentation from a parent node in the syntax tree.
    ///   - outdent: Node types removing a level of indentation.
    ///   - whitespaceDenotesBlocks: `true` to start searching for nodes increasing indentation from the deepest node in the syntax tree.
    public init(indent: [String] = [],
                inheritIndent: [String] = [],
                outdent: [String] = [],
                whitespaceDenotesBlocks: Bool = false) {
        self.indent = indent
        self.inheritIndent = inheritIndent
        self.outdent = outdent
        self.whitespaceDenotesBlocks = whitespaceDenotesBlocks
    }
}

extension TreeSitterIndentationScopes: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterIndentationScopes indent=\(indent)"
        + " inheritIndent=\(inheritIndent)"
        + " outdent=\(outdent)"
        + " whitespaceDenotesBlocks=\(whitespaceDenotesBlocks)]"
    }
}
