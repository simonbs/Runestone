import Foundation

protocol TreeSitterInjectedLanguageMapperDelegate: AnyObject {
    func treeSitterInjectedLanguageMapper(_ mapper: TreeSitterInjectedLanguageMapper, textIn textRange: TreeSitterTextRange) -> String?
}

final class TreeSitterInjectedLanguageMapper {
    weak var delegate: TreeSitterInjectedLanguageMapperDelegate?

    private let captures: [TreeSitterCapture]
    private var languageNameToTextRangeMap: [String: [TreeSitterTextRange]] = [:]
    private var languageNamePendingContent: String?

    init(captures: [TreeSitterCapture]) {
        self.captures = captures
    }

    func map() -> [TreeSitterInjectedLanguage] {
        var result: [TreeSitterInjectedLanguage] = []
        for capture in captures {
            if capture.isTextLanguageName {
                languageNamePendingContent = nil
                if let text = delegate?.treeSitterInjectedLanguageMapper(self, textIn: capture.node.textRange) {
                    languageNamePendingContent = text
                }
            } else if capture.isTextContent {
                if let languagePendingContent = languageNamePendingContent {
                    let id = capture.node.rawValue.id!
                    let textRange = capture.node.textRange
                    let injectedLanguage = TreeSitterInjectedLanguage(id: id, languageName: languagePendingContent, textRange: textRange)
                    result.append(injectedLanguage)
                }
                languageNamePendingContent = nil
            } else {
                let languageName = capture.properties["injection.language"] ?? capture.name
                let id = capture.node.rawValue.id!
                let textRange = capture.node.textRange
                let injectedLanguage = TreeSitterInjectedLanguage(id: id, languageName: languageName, textRange: textRange)
                result.append(injectedLanguage)
                // If we have a pending language we get rid of it. I'm not sure if this is necessary but as of writing this it seems like the safest thing to do.
                languageNamePendingContent = nil
            }
        }
        return result
    }
}

private extension TreeSitterCapture {
    var isTextLanguageName: Bool {
        return name == "language"
    }
    var isTextContent: Bool {
        return name == "content"
    }
}
