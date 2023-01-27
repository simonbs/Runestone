import Runestone
import RunestoneJavaScriptLanguage
import UIKit

final class MainViewController: UIViewController {
    private let contentView = MainView()

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
    }
}
