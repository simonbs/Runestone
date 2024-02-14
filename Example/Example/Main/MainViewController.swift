import Runestone
import RunestoneJavaScriptLanguage
import SwiftUI
import UIKit

final class MainViewController: UIViewController {
    override var textInputContextIdentifier: String? {
        // Returning a unique identifier makes iOS remember the user's selection of keyboard.
        "RunestoneExample.Main"
    }

    private let contentView = MainView()
    #if os(iOS)
    private let toolsView: KeyboardToolsView
    #endif

    init() {
        #if os(iOS)
        toolsView = KeyboardToolsView(textView: contentView.textView)
        #endif
        super.init(nibName: nil, bundle: nil)
        title = "Example"
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIApplication.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIApplication.keyboardWillHideNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 16, *) {
            contentView.textView.isFindInteractionEnabled = true
        }
        #if os(iOS)
        contentView.textView.inputAccessoryView = toolsView
        #endif
        #if compiler(>=5.9) && os(visionOS)
        ornaments = [
            UIHostingOrnament(sceneAnchor: .topTrailing, contentAlignment: .bottomTrailing) {
                HStack {
                    SwiftUIMenuButton(selectionHandler: self)
                        .glassBackgroundEffect()
                }
                .padding(.trailing)
            }
        ]
        #endif
        setupMenuButton()
        setupTextView()
        updateTextViewSettings()
    }
}

private extension MainViewController {
    @available(iOS 16, *)
    @objc private func presentFind() {
        contentView.textView.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    @available(iOS 16, *)
    @objc private func presentFindAndReplace() {
        contentView.textView.findInteraction?.presentFindNavigator(showingReplace: true)
    }

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
        let menuButton = MenuButton.makeConfigured(with: self)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: menuButton)
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

extension MainViewController: MenuSelectionHandler {
    // swiftlint:disable:next cyclomatic_complexity
    func handleSelection(of menuItem: MenuItem) {
        switch menuItem {
        case .presentFind:
            if #available(iOS 16, *) {
                presentFind()
            }
        case .presentFindAndReplace:
            if #available(iOS 16, *) {
                presentFindAndReplace()
            }
        case .presentGoToLine:
            presentGoToLineAlert()
        case .presentThemePicker:
            presentThemePicker()
        case .toggleEditable:
            UserDefaults.standard.isEditable.toggle()
            updateTextViewSettings()
        case .toggleInvisibleCharacters:
            UserDefaults.standard.showInvisibleCharacters.toggle()
            updateTextViewSettings()
        case .toggleHighlightSelectedLine:
            UserDefaults.standard.highlightSelectedLine.toggle()
            updateTextViewSettings()
        case .toggleLineNumbers:
            UserDefaults.standard.showLineNumbers.toggle()
            updateTextViewSettings()
        case .togglePageGuide:
            UserDefaults.standard.showPageGuide.toggle()
            updateTextViewSettings()
        case .toggleSelectable:
            UserDefaults.standard.isSelectable.toggle()
            updateTextViewSettings()
        case .toggleWrapLines:
            UserDefaults.standard.wrapLines.toggle()
            updateTextViewSettings()
        }
    }
}

extension MainViewController: ThemePickerViewControllerDelegate {
    func themePickerViewController(_ viewController: ThemePickerViewController, didPick theme: ThemeSetting) {
        UserDefaults.standard.theme = theme
        view.window?.overrideUserInterfaceStyle = theme.makeTheme().userInterfaceStyle
        updateTextViewSettings()
    }
}
