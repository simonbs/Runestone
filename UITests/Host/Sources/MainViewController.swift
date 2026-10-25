import Runestone
import RunestoneJavaScriptLanguage
import UIKit

final class MainViewController: UIViewController {
    private let contentView = MainView()
    private let dictionaryWord = "runestoneqzv"

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "UI Tests"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let state = TextViewState(text: "", theme: DefaultTheme(), language: .javaScript)
        if ProcessInfo.processInfo.useCRLFLineEndings {
            contentView.textView.lineEndings = .crlf
        }
        contentView.textView.setState(state)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Spelling", style: .plain, target: self, action: #selector(configureSpellChecking)),
            UIBarButtonItem(title: "Dictionary", style: .plain, target: self, action: #selector(configureSpellingDictionary))
        ]
    }

    @objc private func configureSpellChecking() {
        title = "Spelling"
        let textView = contentView.textView
        textView.showLineNumbers = false
        textView.spellCheckingLanguage = "en_US"
        textView.spellCheckingType = .yes
        let text = "mispelled word.\n\nSelect the underlined word to correct it."
        textView.setState(TextViewState(text: text))
        textView.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Undo", style: .plain, target: self, action: #selector(undoSpellingCorrection))
        updateSpellingButton()
    }

    @objc private func configureSpellingDictionary() {
        title = "Dictionary"
        let textView = contentView.textView
        textView.showLineNumbers = false
        textView.spellCheckingLanguage = "en_US"
        textView.spellCheckingType = .yes
        TextView.unlearnSpellingWord(dictionaryWord)
        reloadSpellingDocument()
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "Reload", style: .plain, target: self, action: #selector(reloadSpellingDocument)),
            UIBarButtonItem(title: "Clean Up", style: .plain, target: self, action: #selector(cleanUpSpellingDictionary))
        ]
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Inspect", style: .plain, target: self, action: #selector(inspectSpellingDictionary))
        ]
    }

    @objc private func reloadSpellingDocument() {
        let textView = contentView.textView
        textView.text = "\(dictionaryWord) word.\n\nSelect the first word to ignore or learn its spelling."
        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
    }

    @objc private func cleanUpSpellingDictionary() {
        TextView.unlearnSpellingWord(dictionaryWord)
        contentView.textView.resetIgnoredSpellingWords()
    }

    @objc private func inspectSpellingDictionary() {
        let ignored = contentView.textView.ignoredSpellingWords.contains(dictionaryWord)
        let learned = TextView.hasLearnedSpellingWord(dictionaryWord)
        let message = "Ignored: \(ignored)\nLearned: \(learned)"
        let alert = UIAlertController(title: "Dictionary State", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default))
        present(alert, animated: true)
    }

    private func updateSpellingButton() {
        let title = contentView.textView.spellCheckingType == .yes ? "Spelling On" : "Spelling Off"
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(toggleSpellChecking))
        ]
    }

    @objc private func undoSpellingCorrection() {
        contentView.textView.undoManager?.undo()
    }

    @objc private func toggleSpellChecking() {
        let textView = contentView.textView
        textView.spellCheckingType = textView.spellCheckingType == .yes ? .no : .yes
        textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
        updateSpellingButton()
    }
}
