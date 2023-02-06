import Runestone
import RunestoneJavaScriptLanguage
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIApplication.keyboardWillChangeFrameNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIApplication.keyboardWillHideNotification,
                                               object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
#if compiler(>=5.7)
        if #available(iOS 16, *) {
            contentView.textView.isFindInteractionEnabled = true
        }
#endif
        contentView.textView.inputAccessoryView = toolsView
        setupMenuButton()
        setupTextView()
        updateTextViewSettings()
    }
}

private extension MainViewController {
#if compiler(>=5.7)
    @available(iOS 16, *)
    @objc private func presentFind() {
        contentView.textView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    @available(iOS 16, *)
    @objc private func presentFindAndReplace() {
        contentView.textView.findInteraction?.presentFindNavigator(showingReplace: true)
    }
#endif

    private func setupTextView() {
        var text = ""
        if !ProcessInfo.processInfo.disableTextPersistance, let persistedText = UserDefaults.standard.text {
            text = persistedText
        }
        let themeSetting = UserDefaults.standard.theme
        let theme = themeSetting.makeTheme()
        let state = TextViewState(text: text, theme: theme, language: .javaScript)
        if ProcessInfo.processInfo.useCRLFLineEndings {
            contentView.textView.lineEndings = .crlf
        }
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
        let menu = UIMenu(children: makeFeaturesMenuElements() + makeSettingsMenuElements() + makeThemeMenuElements())
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
    }

    private func makeFeaturesMenuElements() -> [UIMenuElement] {
        var menuElements: [UIMenuElement] = []
#if compiler(>=5.7)
        if #available(iOS 16, *) {
            menuElements += [
                UIMenu(options: .displayInline, children: [
                    UIAction(title: "Find") { [weak self] _ in
                        self?.presentFind()
                    },
                    UIAction(title: "Find and Replace") { [weak self] _ in
                        self?.presentFindAndReplace()
                    }
                ])
            ]
        }
#endif
        menuElements += [
            UIAction(title: "Go to Line") { [weak self] _ in
                self?.presentGoToLineAlert()
            }
        ]
        return menuElements
    }

    private func makeSettingsMenuElements() -> [UIMenuElement] {
        let settings = UserDefaults.standard
        return [
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Show Line Numbers", state: settings.showLineNumbers ? .on : .off) { [weak self] _ in
                    settings.showLineNumbers.toggle()
                    self?.updateTextViewSettings()
                    self?.setupMenuButton()
                },
                UIAction(title: "Show Page Guide", state: settings.showPageGuide ? .on : .off) { [weak self] _ in
                    settings.showPageGuide.toggle()
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
                }
            ]),
            UIMenu(options: .displayInline, children: [
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
        ]
    }

    private func makeThemeMenuElements() -> [UIMenuElement] {
        [
            UIAction(title: "Theme") { [weak self] _ in
                self?.presentThemePicker()
            }
        ]
    }

    private func presentGoToLineAlert() {
        let alertController = UIAlertController(title: "Go To Line", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "42"
            textField.keyboardType = .numberPad
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let doneAction = UIAlertAction(title: "Go", style: .default) { [weak self, weak alertController] _ in
            if let textField = alertController?.textFields?.first, let text = textField.text, !text.isEmpty, let lineNumber = Int(text) {
                let lineIndex = lineNumber - 1
                self?.contentView.textView.goToLine(lineIndex, select: .line)
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(doneAction)
        present(alertController, animated: true)
    }

    private func presentThemePicker() {
        let theme = UserDefaults.standard.theme
        let themePickerViewController = ThemePickerViewController(selectedTheme: theme)
        themePickerViewController.delegate = self
        let navigationController = UINavigationController(rootViewController: themePickerViewController)
        present(navigationController, animated: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        updateInsets(keyboardHeight: 0)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = max(frame.height - view.safeAreaInsets.bottom, 0)
            updateInsets(keyboardHeight: keyboardHeight)
        }
    }

    private func updateInsets(keyboardHeight: CGFloat) {
        contentView.textView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        contentView.textView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
    }
}

extension MainViewController: TextViewDelegate {
    func textViewDidChange(_ textView: TextView) {
        if !ProcessInfo.processInfo.disableTextPersistance {
            UserDefaults.standard.text = textView.text
        }
    }

    func textView(_ textView: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        true
    }
}

extension MainViewController: ThemePickerViewControllerDelegate {
    func themePickerViewController(_ viewController: ThemePickerViewController, didPick theme: ThemeSetting) {
        UserDefaults.standard.theme = theme
        view.window?.overrideUserInterfaceStyle = theme.makeTheme().userInterfaceStyle
        updateTextViewSettings()
    }
}
