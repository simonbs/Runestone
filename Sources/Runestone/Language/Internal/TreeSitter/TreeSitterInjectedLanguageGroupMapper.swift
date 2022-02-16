import Foundation

protocol TreeSitterInjectedLanguageGroupMapperDelegate: AnyObject {
    func treeSitterInjectedLanguageGroupMapper(_ mapper: TreeSitterInjectedLanguageGroupMapper, textIn textRange: TreeSitterTextRange) -> String?
}

final class TreeSitterInjectedLanguageGroupMapper {
    weak var delegate: TreeSitterInjectedLanguageGroupMapperDelegate?

    private let captures: [TreeSitterCapture]
    private var languageNameToTextRangeMap: [String: [TreeSitterTextRange]] = [:]
    private var languageNamePendingContent: String?
    private var didMakeGroups = false

    init(captures: [TreeSitterCapture]) {
        self.captures = captures
    }

    func makeGroups() -> [TreeSitterInjectedLanguageGroup] {
        guard !didMakeGroups else {
            return makeGroupsFromMap()
        }
        for capture in captures {
            if capture.isTextLanguageName {
                languageNamePendingContent = nil
                if let text = delegate?.treeSitterInjectedLanguageGroupMapper(self, textIn: capture.node.textRange) {
                    languageNamePendingContent = text
                }
            } else if capture.isTextContent {
                if let languagePendingContent = languageNamePendingContent {
                    addTextRange(capture.node.textRange, forLanguageNamed: languagePendingContent)
                }
                languageNamePendingContent = nil
            } else {
                let languageName = capture.properties["injection.language"] ?? capture.name
                addTextRange(capture.node.textRange, forLanguageNamed: languageName)
                // If we have a pending language we get rid of it. I'm not sure if this is necessary
                // but as of writing this it seems like the safest thing to do.
                languageNamePendingContent = nil
            }
        }
        didMakeGroups = true
        return makeGroupsFromMap()
    }
}

private extension TreeSitterInjectedLanguageGroupMapper {
    private func addTextRange(_ textRange: TreeSitterTextRange, forLanguageNamed languageName: String) {
        if let existingTextRanges = languageNameToTextRangeMap[languageName] {
            languageNameToTextRangeMap[languageName] = existingTextRanges + [textRange]
        } else {
            languageNameToTextRangeMap[languageName] = [textRange]
        }
    }

    private func makeGroupsFromMap() -> [TreeSitterInjectedLanguageGroup] {
        return languageNameToTextRangeMap.map { languageName, textRanges in
            return TreeSitterInjectedLanguageGroup(languageName: languageName, textRanges: textRanges)
        }
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
