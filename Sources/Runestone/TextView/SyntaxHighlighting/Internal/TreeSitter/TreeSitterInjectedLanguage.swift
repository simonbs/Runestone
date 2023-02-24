import Foundation
import TreeSitter

struct TreeSitterInjectedLanguage {
    let id: UnsafeRawPointer
    let languageName: String
    let textRange: TreeSitterTextRange
}
