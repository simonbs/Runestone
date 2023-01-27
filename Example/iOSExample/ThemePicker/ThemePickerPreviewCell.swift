import Runestone
import RunestoneThemeCommon
import UIKit

final class ThemePickerPreviewCell: UITableViewCell {
    let textView: TextView = {
        let settings = UserDefaults.standard
        let this = TextView.makeConfigured(usingSettings: .standard)
        this.translatesAutoresizingMaskIntoConstraints = false
        return this
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(textView)
        updateBorderColor()
    }

    private func setupLayout() {
        let heightConstraint = textView.heightAnchor.constraint(equalToConstant: 200)
        heightConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            heightConstraint
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }

    private func updateBorderColor() {
        layer.borderColor = UIColor.opaqueSeparator.cgColor
        layer.borderWidth = 1
    }
}

extension ThemePickerPreviewCell {
    struct ViewModel {
        let theme: EditorTheme
        let text: String
    }

    func populate(with viewModel: ViewModel) {
        let languageMode = TreeSitterLanguageMode(language: .javaScript, languageProvider: nil)
        textView.setLanguageMode(languageMode)
        textView.theme = viewModel.theme
        textView.text = viewModel.text
        textView.backgroundColor = viewModel.theme.backgroundColor
        textView.insertionPointColor = viewModel.theme.textColor
        textView.selectionBarColor = viewModel.theme.textColor
        textView.selectionHighlightColor = viewModel.theme.textColor.withAlphaComponent(0.2)
    }
}
