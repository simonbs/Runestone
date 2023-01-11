import Foundation

protocol TreeSitterInjectedLanguageMapperDelegate: AnyObject {
    func treeSitterInjectedLanguageMapper(_ mapper: TreeSitterInjectedLanguageMapper, textIn textRange: TreeSitterTextRange) -> String?
}

final class TreeSitterInjectedLanguageMapper {
    private enum CaptureName {
        static let language = "language"
        static let injectionLanguage = "injection.language"
    }

    private enum CaptureProperty {
        static let injectionLanguage = "injection.language"
    }

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
            if capture.name == CaptureName.language || capture.name == CaptureName.injectionLanguage {
                languageNamePendingContent = nil
                if let text = delegate?.treeSitterInjectedLanguageMapper(self, textIn: capture.node.textRange) {
                    languageNamePendingContent = text
                }
            } else {
                let languageName = languageNamePendingContent ?? capture.properties[CaptureProperty.injectionLanguage] ?? capture.name
                let id = capture.node.rawValue.id!
                let textRange = capture.node.textRange
                let injectedLanguage = TreeSitterInjectedLanguage(id: id, languageName: languageName, textRange: textRange)
                result.append(injectedLanguage)
                languageNamePendingContent = nil
            }
        }
        return result
    }
}
