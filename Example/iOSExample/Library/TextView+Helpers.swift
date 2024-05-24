import Runestone
import RunestoneThemeCommon
import UIKit

extension TextView {
    convenience init(readingSettingsFrom settings: UserDefaults) {
        self.init()
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .always
        autocorrectionType = .no
        autocapitalizationType = .none
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
//        textContainerInset = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
//        lineSelectionDisplayType = .line
//        lineHeightMultiplier = 1.3
//        kern = 0.3
//        pageGuideColumn = 80
//        inputAccessoryView = KeyboardToolsView(textView: textView)
//        characterPairs = [
//            BasicCharacterPair(leading: "(", trailing: ")"),
//            BasicCharacterPair(leading: "{", trailing: "}"),
//            BasicCharacterPair(leading: "[", trailing: "]"),
//            BasicCharacterPair(leading: "\"", trailing: "\""),
//            BasicCharacterPair(leading: "'", trailing: "'")
//        ]
        let theme = settings.theme.makeTheme()
        applyTheme(theme)
        applySettings(from: settings)
    }

    func applyTheme(_ theme: EditorTheme) {
//        self.theme = theme
        backgroundColor = theme.backgroundColor
//        insertionPointColor = theme.textColor
//        insertionPointForegroundColor = theme.backgroundColor
//        insertionPointInvisibleCharacterForegroundColor = theme.backgroundColor.withAlphaComponent(0.8)
        selectionBarColor = theme.textColor
        selectionHighlightColor = theme.textColor.withAlphaComponent(0.2)
    }

    func applySettings(from settings: UserDefaults) {
//        showLineNumbers = settings.showLineNumbers
        showTabs = settings.showInvisibleCharacters
        showSpaces = settings.showInvisibleCharacters
        showLineBreaks = settings.showInvisibleCharacters
//        isLineWrappingEnabled = settings.wrapLines
//        isEditable = settings.isEditable
//        isSelectable = settings.isSelectable
//        lineSelectionDisplayType = settings.highlightSelectedLine ? .line : .disabled
//        showPageGuide = settings.showPageGuide
//        insertionPointShape = settings.insertionPointShape.insertionPointShape
        if #available(iOS 17, *) {
            inlinePredictionType = settings.isInlinePredictionEnabled ? .yes : .no
        }
    }
}
