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
    private var navigationDocumentLength = 0
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
        if ProcessInfo.processInfo.navigationDocumentName != nil {
            contentView.textView.isLineWrappingEnabled = ProcessInfo.processInfo.environment["RUNESTONE_WRAP_LINES"] != "0"
            contentView.textView.showLineNumbers = true
        }
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
        var language = UserDefaults.standard.sampleLanguage
        if let name = ProcessInfo.processInfo.navigationDocumentName {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                text = try String(contentsOf: documents.appendingPathComponent(name), encoding: .utf8)
                navigationDocumentLength = (text as NSString).length
                if ["md", "markdown"].contains(documents.appendingPathComponent(name).pathExtension.lowercased()) {
                    language = .markdown
                }
            } catch {
                text = "Could not load navigation document: \(error.localizedDescription)"
            }
        } else if !ProcessInfo.processInfo.disableTextPersistance, let persistedText = UserDefaults.standard.text {
            text = persistedText
        }
        let themeSetting = UserDefaults.standard.theme
        let theme = themeSetting.makeTheme()
        let state = TextViewState(text: text, theme: theme, language: language.treeSitterLanguage,
                                  languageProvider: ExampleLanguageProvider())
        if ProcessInfo.processInfo.useCRLFLineEndings {
            contentView.textView.lineEndings = .crlf
        }
        contentView.textView.editorDelegate = self
        contentView.textView.setState(state)
    }

    private func showFoldingExample(_ language: CodeSample.Language) {
        let settings = UserDefaults.standard
        settings.sampleLanguage = language
        settings.codeFoldingEnabled = true
        settings.showLineNumbers = true
        let text = language == .markdown ? CodeSample.markdownFolding : CodeSample.javaScriptFolding
        if !ProcessInfo.processInfo.disableTextPersistance {
            settings.text = text
        }
        navigationDocumentLength = (text as NSString).length
        let state = TextViewState(text: text, theme: settings.theme.makeTheme(),
                                  language: language.treeSitterLanguage,
                                  languageProvider: ExampleLanguageProvider())
        contentView.textView.setState(state)
        updateTextViewSettings()
        contentView.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    private func jumpToTop() {
        jump(to: 0)
    }

    private func jumpToBottom() {
        jump(to: navigationDocumentLength)
    }

    private func jump(to location: Int) {
        let start = CACurrentMediaTime()
        contentView.textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        contentView.textView.layoutIfNeeded()
        let milliseconds = (CACurrentMediaTime() - start) * 1_000
        print("Navigation to \(location): \(milliseconds) ms")
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
        if ProcessInfo.processInfo.navigationDocumentName != nil {
            navigationDocumentLength = (textView.text as NSString).length
        }
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
        case .jumpToTop:
            jumpToTop()
        case .jumpToBottom:
            jumpToBottom()
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
        case .showJavaScriptFoldingExample:
            showFoldingExample(.javaScript)
        case .showMarkdownFoldingExample:
            showFoldingExample(.markdown)
        case .toggleCodeFolding:
            UserDefaults.standard.codeFoldingEnabled.toggle()
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
            UserDefaults.standard.wrapLines = !contentView.textView.isLineWrappingEnabled
            updateTextViewSettings()
        case .toggleSpellChecking:
            UserDefaults.standard.checkSpelling.toggle()
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
