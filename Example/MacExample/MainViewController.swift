import Cocoa
import Runestone
import RunestoneOneDarkTheme
import RunestoneThemeCommon
import RunestoneTomorrowNightTheme
import RunestoneTomorrowTheme

final class MainViewController: NSViewController {
    private let textView: TextView = {
        let this = TextView()
        this.translatesAutoresizingMaskIntoConstraints = false
        this.textContainerInset = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        this.showTabs = true
        this.showSpaces = true
        this.showLineBreaks = true
        this.showSoftLineBreaks = true
        this.lineHeightMultiplier = 1.2
        this.kern = 0.3
        return this
    }()

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
        applyTheme(OneDarkTheme())
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
    }
}
