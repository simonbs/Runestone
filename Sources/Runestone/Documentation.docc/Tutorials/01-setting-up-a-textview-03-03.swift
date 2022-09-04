import Foundation

extension UserDefaults {
    private enum Key {
        static let text = "text"
    }

    var text: String {
        get {
            return string(forKey: Key.text) ?? ""
        }
        set {
            set(newValue, forKey: Key.text)
        }
    }
}
