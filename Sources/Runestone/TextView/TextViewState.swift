//
//  TextViewState.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import Foundation

public final class TextViewState {
    let text: String
    let stringView: StringView
    let theme: Theme
    let lineManager: LineManager
    let languageMode: InternalLanguageMode

    public private(set) var detectedIndentStrategy: DetectedIndentStrategy = .unknown

    public init(text: String, theme: Theme, language: TreeSitterLanguage, languageProvider: TreeSitterLanguageProvider) {
        self.text = text
        self.theme = theme
        self.stringView = StringView(string: NSMutableString(string: text))
        self.lineManager = LineManager(stringView: stringView)
        self.languageMode = TreeSitterInternalLanguageMode(
            language: language,
            languageProvider: languageProvider,
            stringView: stringView,
            lineManager: lineManager)
        prepare()
    }

    public init(text: String, theme: Theme) {
        self.text = text
        self.theme = theme
        self.stringView = StringView(string: NSMutableString(string: text))
        self.lineManager = LineManager(stringView: stringView)
        self.languageMode = PlainTextInternalLanguageMode()
        prepare()
    }
}

private extension TextViewState {
    private func prepare() {
        let nsString = text as NSString
        lineManager.estimatedLineHeight = theme.font.totalLineHeight
        lineManager.rebuild(from: nsString)
        languageMode.parse(nsString)
        detectedIndentStrategy = languageMode.detectIndentStrategy()
    }
}
