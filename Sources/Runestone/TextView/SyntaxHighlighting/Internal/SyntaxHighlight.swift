import Foundation

/// A platform-neutral syntax capture after it has been clipped to the requested text.
///
/// Theme resolution intentionally happens after this model is produced. This keeps
/// Tree-sitter capture discovery useful to renderers that do not use UIKit while the
/// editor remains responsible for translating highlight names into display styles.
/// It remains internal until a document-level consumer defines snapshot ownership,
/// absolute-range and cancellation semantics, and a platform-neutral style palette.
struct SyntaxHighlight: Equatable {
    let range: NSRange
    let name: String
}
