import Cocoa
import Runestone
import RunestoneOneDarkTheme
import RunestoneThemeCommon
import RunestoneTomorrowNightTheme
import RunestoneTomorrowTheme

final class MainViewController: NSViewController {
    private let theme: EditorTheme = OneDarkTheme()
    private let textView: TextView = {
        let this = TextView()
        this.translatesAutoresizingMaskIntoConstraints = false
        this.textContainerInset = NSEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        this.showLineNumbers = true
        this.showTabs = true
        this.showSpaces = true
        this.showLineBreaks = true
        this.showSoftLineBreaks = true
        this.lineHeightMultiplier = 1.2
        this.kern = 0.3
        this.lineSelectionDisplayType = .line
        this.gutterLeadingPadding = 4
        this.gutterTrailingPadding = 4
        this.isLineWrappingEnabled = false
        this.indentStrategy = .space(length: 2)
        return this
    }()

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.appearance = NSAppearance(named: .vibrantDark)
        setupTextView()
        applyTheme(theme)
        let state = TextViewState(text: "", theme: theme, language: .javaScript)
        textView.setState(state)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.backgroundColor = theme.backgroundColor
    }
}

private extension MainViewController {
    private func setupTextView() {
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyTheme(_ theme: EditorTheme) {
        textView.theme = theme
        textView.wantsLayer = true
        textView.layer?.backgroundColor = theme.backgroundColor.cgColor
        textView.insertionPointColor = theme.textColor
    }
}
