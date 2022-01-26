import Foundation

extension UserDefaults {
    private enum Key {
        static let text = "RunestoneExample.text"
        static let showLineNumbers = "RunestoneExample.showLineNumbers"
        static let wrapLines = "RunestoneExample.wrapLines"
        static let highlightSelectedLine = "RunestoneExample.highlightSelectedLine"
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

    func registerDefaults() {
        let text = """
/**
 * This is a Runestone text view with syntax highlighting
 * for the JavaScript programming language.
 */

let names = ["Steve Jobs", "Tim Cook", "Eddy Cue"]
let years = [1955, 1960, 1964]
printNamesAndYears(names, years)

// Print the year each person was born.
function printNamesAndYears(names, years) {
  for (let i = 0; i < names.length; i++) {
    console.log(names[i] + " was born in " + years[i])
  }
}
"""
        register(defaults: [
            Key.text: text,
            Key.showLineNumbers: true,
            Key.wrapLines: false,
            Key.highlightSelectedLine: true
        ])
    }
}
