import _RunestoneTreeSitter

struct TreeSitterInjectedLanguage {
    let id: UnsafeRawPointer
    let languageName: String
    let textRange: TreeSitterTextRange
}
