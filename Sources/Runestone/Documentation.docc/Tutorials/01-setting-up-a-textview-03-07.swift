import Runestone
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TextCompanion"
        navigationController?.navigationBar.scrollEdgeAppearance = UINavigationBarAppearance()
        let textView = TextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.editorDelegate = self
        textView.backgroundColor = .systemBackground
        setCustomization(on: textView)
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setCustomization(on textView: TextView) {
        // ...
    }
}

extension ViewController: TextViewDelegate {
    func textViewDidChange(_ textView: TextView) {
        UserDefaults.standard.text = textView.text
    }
}
