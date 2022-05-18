import Runestone
import RunestoneJavaScriptLanguage
import RunestoneTomorrowTheme
import UIKit

final class MainViewController: UIViewController {
    override var textInputContextIdentifier: String? {
        // Returning a unique identifier makes iOS remember the user's selection of keyboard.
        return "RunestoneExample.Main"
    }

    private let contentView = MainView()
    private let toolsView: KeyboardToolsView

    init() {
        toolsView = KeyboardToolsView(textView: contentView.textView)
        super.init(nibName: nil, bundle: nil)
        title = "Example"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.textView.inputAccessoryView = toolsView
        setupMenuButton()
        setupTextView()
        updateTextViewSettings()
    }
}

private extension MainViewController {
    private func setupTextView() {
        let text = UserDefaults.standard.text ?? ""
        let state = TextViewState(text: text, theme: TomorrowTheme(), language: .javaScript)
        contentView.textView.editorDelegate = self
        contentView.textView.setState(state)
    }

    private func updateTextViewSettings() {
        let settings = UserDefaults.standard
        let theme = settings.theme.makeTheme()
        contentView.textView.applyTheme(theme)
        contentView.textView.applySettings(from: settings)
    }

    private func setupMenuButton() {
        let settings = UserDefaults.standard
        let settingsMenu = UIMenu(options: .displayInline, children: [
            UIAction(title: "Show Line Numbers", state: settings.showLineNumbers ? .on : .off) { [weak self] _ in
                settings.showLineNumbers.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            },
            UIAction(title: "Show Invisible Characters", state: settings.showInvisibleCharacters ? .on : .off) { [weak self] _ in
                settings.showInvisibleCharacters.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            },
            UIAction(title: "Wrap Lines", state: settings.wrapLines ? .on : .off) { [weak self] _ in
                settings.wrapLines.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            },
            UIAction(title: "Highlight Selected Line", state: settings.highlightSelectedLine ? .on : .off) { [weak self] _ in
                settings.highlightSelectedLine.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            },
            UIAction(title: "Show Page Guide", state: settings.showPageGuide ? .on : .off) { [weak self] _ in
                settings.showPageGuide.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            },
            UIAction(title: "Allow Editing", state: settings.isEditable ? .on : .off) { [weak self] _ in
                settings.isEditable.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            },
            UIAction(title: "Allow Selection", state: settings.isSelectable ? .on : .off) { [weak self] _ in
                settings.isSelectable.toggle()
                self?.updateTextViewSettings()
                self?.setupMenuButton()
            }
        ])
        let miscMenu = UIMenu(options: .displayInline, children: [
            UIAction(title: "Theme") { [weak self] _ in
                self?.presentThemePicker()
            }
        ])
        let menu = UIMenu(children: [settingsMenu, miscMenu])
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), primaryAction: nil, menu: menu)
    }
}

private extension MainViewController {
    private func presentThemePicker() {
        let theme = UserDefaults.standard.theme
        let themePickerViewController = ThemePickerViewController(selectedTheme: theme)
        themePickerViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: themePickerViewController)
        present(navigationController, animated: true)
    }
}

extension MainViewController: TextViewDelegate {
    func textViewDidChange(_ textView: TextView) {
        UserDefaults.standard.text = textView.text
    }
}

extension MainViewController: ThemePickerViewControllerDelegate {
    func themePickerViewController(_ viewController: ThemePickerViewController, didPick theme: ThemeSetting) {
        UserDefaults.standard.theme = theme
        view.window?.overrideUserInterfaceStyle = theme.makeTheme().userInterfaceStyle
        updateTextViewSettings()
    }
}
