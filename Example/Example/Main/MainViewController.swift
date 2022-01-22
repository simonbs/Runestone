//
//  ViewController.swift
//  Example
//
//  Created by Simon on 19/01/2022.
//

import Runestone
import TreeSitterJavaScriptRunestone
import UIKit

final class MainViewController: UIViewController {
    private let contentView = MainView()

    init() {
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
        setupMenuButton()
        setupTextView()
        updateTextViewSettings()
    }
}

private extension MainViewController {
    private func setupTextView() {
        let text = UserDefaults.standard.text ?? ""
        let state = TextViewState(text: text, theme: TomorrowTheme(), language: .javaScript, languageProvider: self)
        contentView.textView.editorDelegate = self
        contentView.textView.setState(state)
    }

    private func updateTextViewSettings() {
        let settings = UserDefaults.standard
        contentView.textView.showLineNumbers = settings.showLineNumbers
        contentView.textView.isLineWrappingEnabled = settings.wrapLines
        contentView.textView.lineSelectionDisplayType = settings.highlightSelectedLine ? .line : .disabled
    }

    private func setupMenuButton() {
        let settings = UserDefaults.standard
        let menu = UIMenu(children: [
            UIAction(title: "Show Line Numbers", state: settings.showLineNumbers ? .on : .off) { [weak self] _ in
                settings.showLineNumbers.toggle()
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
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), primaryAction: nil, menu: menu)
    }
}

extension MainViewController: TreeSitterLanguageProvider {
    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage? {
        return nil
    }
}

extension MainViewController: TextViewDelegate {
    func textViewDidChange(_ textView: TextView) {
        UserDefaults.standard.text = textView.text
    }
}
