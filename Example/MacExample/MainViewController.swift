import Cocoa
import Runestone

final class MainViewController: NSViewController {
    private let textView: TextView = {
        let this = TextView()
        this.translatesAutoresizingMaskIntoConstraints = false
        return this
    }()

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.purple.cgColor
        setupTextView()
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
}
