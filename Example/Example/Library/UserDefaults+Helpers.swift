import Foundation

extension UserDefaults {
    private enum Key {
        static let text = "RunestoneExample.text"
        static let showLineNumbers = "RunestoneExample.showLineNumbers"
        static let showInvisibleCharacters = "RunestoneExample.showInvisibleCharacters"
        static let wrapLines = "RunestoneExample.wrapLines"
        static let highlightSelectedLine = "RunestoneExample.highlightSelectedLine"
        static let showPageGuide = "RunestoneExample.showPageGuide"
        static let theme = "RunestoneExample.theme"
    }

    var text: String? {
        get {
            return string(forKey: Key.text)
        }
        set {
            set(newValue, forKey: Key.text)
        }
    }
    var showLineNumbers: Bool {
        get {
            return bool(forKey: Key.showLineNumbers)
        }
        set {
            set(newValue, forKey: Key.showLineNumbers)
        }
    }
    var showInvisibleCharacters: Bool {
        get {
            return bool(forKey: Key.showInvisibleCharacters)
        }
        set {
            set(newValue, forKey: Key.showInvisibleCharacters)
        }
    }
    var wrapLines: Bool {
        get {
            return bool(forKey: Key.wrapLines)
        }
        set {
            set(newValue, forKey: Key.wrapLines)
        }
    }
    var highlightSelectedLine: Bool {
        get {
            return bool(forKey: Key.highlightSelectedLine)
        }
        set {
            set(newValue, forKey: Key.highlightSelectedLine)
        }
    }
    var showPageGuide: Bool {
        get {
            return bool(forKey: Key.showPageGuide)
        }
        set {
            set(newValue, forKey: Key.showPageGuide)
        }
    }
    var theme: ThemeSetting {
        get {
            if let rawValue = string(forKey: Key.theme), let setting = ThemeSetting(rawValue: rawValue) {
                return setting
            } else {
                return .tomorrow
            }
        }
        set {
            set(newValue.rawValue, forKey: Key.theme)
        }
    }

    func registerDefaults() {
        register(defaults: [
            Key.text: CodeSample.default,
            Key.showLineNumbers: true,
            Key.wrapLines: false,
            Key.highlightSelectedLine: true
        ])
    }
}
