//
//  TextView+Helpers.swift
//  Example
//
//  Created by Simon on 31/01/2022.
//

import Runestone
import UIKit

extension TextView {
    static func makeConfigured(usingSettings settings: UserDefaults) -> TextView {
        let textView = TextView()
        textView.alwaysBounceVertical = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        textView.lineSelectionDisplayType = .line
        textView.lineHeightMultiplier = 1.3
        textView.kern = 0.3
        textView.pageGuideColumn = 80
        textView.inputAccessoryView = KeyboardToolsView(textView: textView)
        textView.characterPairs = [
            BasicCharacterPair(leading: "(", trailing: ")"),
            BasicCharacterPair(leading: "{", trailing: "}"),
            BasicCharacterPair(leading: "[", trailing: "]"),
            BasicCharacterPair(leading: "\"", trailing: "\""),
            BasicCharacterPair(leading: "'", trailing: "'")
        ]
        let theme = settings.theme.makeTheme()
        textView.applyTheme(theme)
        textView.applySettings(from: settings)
        return textView
    }

    func applyTheme(_ theme: EditorTheme) {
        self.theme = theme
        backgroundColor = theme.backgroundColor
        insertionPointColor = theme.textColor
        selectionBarColor = theme.textColor
        selectionHighlightColor = theme.textColor.withAlphaComponent(0.2)
    }

    func applySettings(from settings: UserDefaults) {
        showLineNumbers = settings.showLineNumbers
        showTabs = settings.showInvisibleCharacters
        showSpaces = settings.showInvisibleCharacters
        showLineBreaks = settings.showInvisibleCharacters
        isLineWrappingEnabled = settings.wrapLines
        lineSelectionDisplayType = settings.highlightSelectedLine ? .line : .disabled
        showPageGuide = settings.showPageGuide
    }
}
